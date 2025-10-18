# entrypoint.sh
#!/usr/bin/env bash
set -e
: "${WEBHOOK_URL:=https://${HEROKU_APP_NAME}.herokuapp.com/}"
export WEBHOOK_URL
if [ -n "$DATABASE_URL" ]; then
  export DB_TYPE=postgresdb
  export DB_POSTGRESDB_CONNECTION_STRING="$DATABASE_URL"
fi
exec n8n start
