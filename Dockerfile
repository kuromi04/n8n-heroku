FROM n8nio/n8n:latest
# Heroku asigna $PORT; n8n escucha en N8N_PORT
ENV N8N_HOST=0.0.0.0
ENV N8N_PORT=8080
EXPOSE 8080
# Heroku inyecta DATABASE_URL; n8n lo leerá si configuras envs abajo
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
