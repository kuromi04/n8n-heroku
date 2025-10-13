#!/usr/bin/env bash
set -euo pipefail

DEFAULT_CMD=("n8n" "start")

log() {
  local timestamp
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '[%s] %s\n' "$timestamp" "$*"
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

maybe_update_n8n() {
  local auto_update
  auto_update="${N8N_AUTO_UPDATE:-true}"

  if [ "$auto_update" != "true" ]; then
    log "Skipping automatic n8n updates (N8N_AUTO_UPDATE=${auto_update})."
    return
  fi

  if ! command -v npm >/dev/null 2>&1; then
    log "npm is not available; cannot update n8n automatically."
    return
  fi

  local target_version
  target_version="$(desired_n8n_version)"
  if [ -z "$target_version" ]; then
    log "Unable to determine the desired n8n version; skipping update."
    return
  fi

  local installed_version
  installed_version="$(current_n8n_version)"

  if [ "$installed_version" = "$target_version" ]; then
    log "n8n ${installed_version} is already installed."
    return
  fi

  log "Updating n8n from ${installed_version:-unknown} to ${target_version}."
  if npm install -g "n8n@${target_version}" --loglevel=error --no-fund; then
    log "Successfully updated n8n to version ${target_version}."
  else
    log "Failed to update n8n; continuing with version ${installed_version:-unknown}."
  fi
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
