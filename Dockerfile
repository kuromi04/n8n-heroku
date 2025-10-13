# syntax=docker/dockerfile:1

ARG N8N_VERSION=latest
FROM n8nio/n8n:${N8N_VERSION}

# Run as root to allow runtime updates of the n8n CLI when requested.
USER root

# Replace the entrypoint with a Heroku-friendly bootstrap script that
# prepares the database configuration and optionally keeps n8n updated.
COPY entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
ENV N8N_RUNTIME_DIR=/tmp/n8n-runtime

CMD ["n8n", "start"]
