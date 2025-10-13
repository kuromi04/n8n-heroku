#!/usr/bin/env bash
set -euo pipefail

DEFAULT_CMD=("n8n" "start")
N8N_RUNTIME_DIR="${N8N_RUNTIME_DIR:-/tmp/n8n-runtime}"

log() {
  local timestamp
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '[%s] %s\n' "$timestamp" "$*"
}

normalize_bool() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON)
      printf 'true'
      ;;
    *)
      printf 'false'
      ;;
  esac
}

configure_port() {
  if [ -n "${PORT:-}" ]; then
    export N8N_PORT="$PORT"
    log "Using Heroku PORT=${PORT} for N8N_PORT."
  else
    log "PORT is not defined; using the default n8n port."
  fi
}

configure_database() {
  if [ -z "${DATABASE_URL:-}" ]; then
    log "DATABASE_URL not provided; skipping database configuration."
    return
  fi

  local db_values
  IFS=$'\n' read -r -d '' -a db_values < <(node <<'NODE' && printf '\0'
const urlValue = process.env.DATABASE_URL;
try {
  const parsed = new URL(urlValue);
  if (!/^postgres/i.test(parsed.protocol)) {
    console.log('');
    console.log('');
    console.log('');
    console.log('');
    console.log('');
    process.exit(0);
  }

  const withoutLeadingSlash = parsed.pathname ? parsed.pathname.replace(/^\//, '') : '';
  console.log(parsed.hostname ?? '');
  console.log(parsed.port || '5432');
  console.log(parsed.username || '');
  console.log(parsed.password || '');
  console.log(withoutLeadingSlash);
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
NODE
  ) || {
    log "Failed to parse DATABASE_URL; aborting.";
    exit 1
  }

  # If the protocol was not Postgres we bail out silently.
  if [ "${#db_values[@]}" -eq 0 ] || [ -z "${db_values[0]}${db_values[2]}${db_values[4]}" ]; then
    log "DATABASE_URL is not a Postgres connection string; skipping database configuration."
    return
  fi

  export DB_TYPE=postgresdb
  export DB_POSTGRESDB_HOST="${db_values[0]}"
  export DB_POSTGRESDB_PORT="${db_values[1]}"
  export DB_POSTGRESDB_USER="${db_values[2]}"
  export DB_POSTGRESDB_PASSWORD="${db_values[3]}"
  export DB_POSTGRESDB_DATABASE="${db_values[4]}"

  log "Configured Postgres database ${DB_POSTGRESDB_DATABASE} on ${DB_POSTGRESDB_HOST}:${DB_POSTGRESDB_PORT}."
}

current_n8n_version() {
  n8n --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true
}

desired_n8n_version() {
  local requested
  requested="${N8N_VERSION:-latest}"
  if [ "$requested" = "latest" ]; then
    npm view n8n version 2>/dev/null || true
  else
    printf '%s\n' "$requested"
  fi
}

runtime_bin_dir() {
  printf '%s/bin' "$N8N_RUNTIME_DIR"
}

activate_runtime_dir() {
  local bin_dir
  bin_dir="$(runtime_bin_dir)"
  if [ -d "$bin_dir" ] && [[ ":$PATH:" != *":$bin_dir:"* ]]; then
    export PATH="$bin_dir:$PATH"
    hash -r 2>/dev/null || true
  fi
}

install_n8n_runtime() {
  local version
  local force
  local previous_version
  version="$1"
  force="${2:-false}"
  previous_version="${3:-}"

  case "$force" in
    true|TRUE)
      force=true
      ;;
    *)
      force=false
      ;;
  esac

  if [ "$force" = "true" ]; then
    log "Clearing runtime directory ${N8N_RUNTIME_DIR} before reinstalling n8n ${version}."
    rm -rf "$N8N_RUNTIME_DIR"
  elif [ -n "$previous_version" ] && [ "$previous_version" != "$version" ]; then
    log "Removing previously installed n8n ${previous_version} before upgrading to ${version}."
    rm -rf "${N8N_RUNTIME_DIR}/lib/node_modules/n8n" "${N8N_RUNTIME_DIR}/bin/n8n"
  fi

  mkdir -p "$N8N_RUNTIME_DIR"
  if ! command -v npm >/dev/null 2>&1; then
    log "npm is not available; cannot install n8n ${version}."
    return 1
  fi

  if [ "$force" = "true" ]; then
    log "Clearing npm cache before the forced installation."
    npm cache clean --force >/dev/null 2>&1 || true
  fi

  log "Installing n8n ${version} into ${N8N_RUNTIME_DIR}."
  local install_args
  install_args=(--global --loglevel=error --no-fund --unsafe-perm --prefix "$N8N_RUNTIME_DIR")
  if [ "$force" = "true" ]; then
    install_args+=(--force)
  fi

  if npm install "${install_args[@]}" "n8n@${version}"; then
    activate_runtime_dir
    local resolved
    resolved="$(runtime_n8n_version)"
    if [ "$resolved" != "$version" ]; then
      log "Warning: expected n8n ${version} after installation but detected ${resolved:-unknown}."
    else
      log "Successfully installed n8n ${version}."
    fi
    return 0
  fi

  log "Failed to install n8n ${version}."
  return 1
}

runtime_n8n_version() {
  local runtime_bin
  runtime_bin="$(runtime_bin_dir)/n8n"
  if [ -x "$runtime_bin" ]; then
    "$runtime_bin" --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true
  fi
}

maybe_update_n8n() {
  local auto_update
  auto_update="${N8N_AUTO_UPDATE:-true}"
  local force_install
  force_install="${N8N_FORCE_INSTALL:-false}"

  auto_update="$(normalize_bool "$auto_update")"
  force_install="$(normalize_bool "$force_install")"

  mkdir -p "$N8N_RUNTIME_DIR"
  activate_runtime_dir

  local target_version
  target_version="$(desired_n8n_version)"
  if [ -z "$target_version" ]; then
    log "Unable to determine the desired n8n version; skipping update."
    return
  fi

  local installed_version
  installed_version="$(runtime_n8n_version)"
  if [ -z "$installed_version" ]; then
    installed_version="$(current_n8n_version)"
  fi

  if [ "$installed_version" = "$target_version" ] && [ "$force_install" != "true" ]; then
    log "n8n ${installed_version} is already available."
    return
  fi

  if [ "$installed_version" = "$target_version" ] && [ "$force_install" = "true" ]; then
    log "Reinstalling n8n ${target_version} because N8N_FORCE_INSTALL=true."
  fi

  if [ "$auto_update" != "true" ] && [ "$force_install" != "true" ]; then
    log "n8n ${installed_version:-unknown} does not match desired ${target_version}, but automatic updates are disabled."
    return
  fi

  if install_n8n_runtime "$target_version" "$force_install" "$installed_version"; then
    if [ "$force_install" = "true" ]; then
      log "Forced installation completed; unset N8N_FORCE_INSTALL to avoid reinstalling on every boot."
      export N8N_FORCE_INSTALL=false
    fi
    return
  fi

  log "Continuing with existing n8n ${installed_version:-unknown}."
}

main() {
  if [ "$#" -eq 0 ]; then
    set -- "${DEFAULT_CMD[@]}"
  fi

  configure_port
  configure_database
  maybe_update_n8n

  log "Starting n8n with command: $*"
  exec "$@"
}

main "$@"
