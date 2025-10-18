# Dockerfile
FROM n8nio/n8n:latest
ENV N8N_HOST=0.0.0.0
ENV N8N_PORT=8080
EXPOSE 8080
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
