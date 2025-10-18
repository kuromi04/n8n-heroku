# n8n-heroku

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/kuromi04/n8n-heroku2025)




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

During startup the entrypoint script compares the installed version with the desired one and installs upgrades when required, ensuring that only n8n itself changes while the rest of the environment remains stable.
