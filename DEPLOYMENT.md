# Deployment configuration

The tracked Kamal configuration is safe to publish and obtains installation-
specific values from the environment.

Set these values before running Kamal:

- `DEPLOY_HOST` (required): application host and deployment server
- `DEPLOY_SSH_USER` (default: `root`)
- `DEPLOY_STORAGE_PATH` (default: `/var/lib/kamal/campfire/storage`)
- `DEPLOY_STORAGE_UID` (default: `1000`, the container's Rails user)
- `KAMAL_SERVICE` (default: `campfire`)
- `KAMAL_IMAGE` (default: `campfire`)
- `KAMAL_REGISTRY` (default: `localhost:5555`)
- `KAMAL_BUILDER_ARCH` (default: `amd64`)

Copy `.kamal/secrets.example` to `.kamal/secrets` and configure its secret
source locally. Both `.kamal/secrets` and `config/credentials.yml.enc` are
ignored because they belong to an individual installation. Store their source
copies in a password manager or deployment system, not in Git.

The application expects `SECRET_KEY_BASE`, `VAPID_PUBLIC_KEY`, and
`VAPID_PRIVATE_KEY` at runtime. `RAILS_MASTER_KEY` is available to the image
builder when a private encrypted credentials file is installed locally.

The pre-deploy hook connects to `DEPLOY_HOST` and creates the persistent storage
directory with ownership matching `DEPLOY_STORAGE_UID`. The deployment user
must be allowed to create and change ownership of that directory.

Kamal Proxy terminates TLS and forwards requests to the application on port 80.
`DISABLE_SSL` prevents the application container from attempting to terminate
TLS a second time; it does not disable HTTPS at the public proxy.
