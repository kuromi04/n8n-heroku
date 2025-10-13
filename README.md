# n8n-heroku

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://dashboard.heroku.com/new?template=https://github.com/kuromi04/n8n-heroku2025.git)
[![Actualizar n8n](https://img.shields.io/badge/Actualizar%20n8n-Deploy%20Update-79589f?logo=heroku&logoColor=white)](https://dashboard.heroku.com/new?template=https://github.com/kuromi04/n8n-heroku2025.git&env[N8N_FORCE_INSTALL]=true)

## n8n - Free and open fair-code licensed node based Workflow Automation Tool.

This is a [Heroku](https://heroku.com/)-focused container implementation of [n8n](https://n8n.io/).

Use the **Deploy to Heroku** button above to launch n8n on Heroku. When deploying, make sure to check all configuration options
and adjust them to your needs. It's especially important to set `N8N_ENCRYPTION_KEY` to a random secure value.

Refer to the [Heroku n8n tutorial](https://docs.n8n.io/hosting/server-setups/heroku/) for more information.

If you have questions after trying the tutorials, check out the [forums](https://community.n8n.io/).

## Automatic n8n version management

This container keeps the n8n CLI up to date without requiring code changes:

- Set the `N8N_VERSION` config var to pin a specific n8n release. The default value (`latest`) resolves to the newest stable version on each deploy or dyno restart.
- Automatic upgrades can be disabled by setting `N8N_AUTO_UPDATE=false` if you prefer to manage updates manually.
- To force an upgrade of the currently requested version (for example after a new `latest` is published), set `N8N_FORCE_INSTALL=true` or use the **Actualizar n8n** button above and select your existing application in the Heroku dialog. The flag will trigger a clean reinstall on the next deploy without touching other configuration and clears npm's cache to make sure the newest build is fetched.

During startup the entrypoint script compares the installed version with the desired one and installs upgrades when required, ensuring that only n8n itself changes while the rest of the environment remains stable.

Updated releases are placed in a writable runtime directory (default `/tmp/n8n-runtime`) and prepended to the `PATH`, so the Heroku slug remains untouched. The runtime installer automatically clears any previously staged binaries before installing the requested version. You can change the directory by defining the optional `N8N_RUNTIME_DIR` config var as long as the location is writable at boot time.

Tanto la fase de *release* como los *dynos* web reutilizan el mismo entrypoint del contenedor, por lo que cada despliegue verifica si hay una versión más reciente de n8n, la instala antes de ejecutar las migraciones de base de datos y sólo entonces expone la aplicación.
