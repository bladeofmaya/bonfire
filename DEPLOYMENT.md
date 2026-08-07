# Deploying Bonfire

Bonfire uses [Kamal](https://kamal-deploy.org/) to prepare a Linux server, build
the application image, run Kamal Proxy with automatic HTTPS, and deploy the
application. The `bin/bonfire` command keeps the common workflow in one place.

## Requirements

You need a local checkout with Ruby, Docker, SSH, Git, and Kamal 2 installed.
The target should be a Linux server reachable over SSH. Its DNS name must point
to the server, and inbound ports 80 and 443 must be open before the first deploy.

## First deployment

Run the interactive setup:

```sh
bin/bonfire setup
```

Setup asks for the deployment hostname, writes local configuration, generates
the application and Web Push secrets, checks SSH access, and shows the complete
target configuration. It asks for confirmation before it changes the server.
After confirmation it runs `kamal server bootstrap` followed by `kamal setup`.

To prepare files without changing a server:

```sh
bin/bonfire setup --host chat.example.com --configure-only
```

For deliberate non-interactive setup, supply the required values and `--yes`:

```sh
bin/bonfire setup --host chat.example.com --user root --yes
```

Run `bin/bonfire setup --help` for all overrides.

## Inspecting a deployment

```sh
bin/bonfire status
```

This reports the host, SSH user, service/image names, registry, architecture,
storage, HTTPS mode, secret presence, Git revision, DNS, SSH/Docker state, and
Kamal container details. Secret values are never printed. Use
`bin/bonfire status --local` to skip network and remote checks.

## Subsequent deployments

```sh
bin/bonfire deploy
```

The command requires complete configuration, required secrets, local tools, and
a clean Git worktree. It shows the target and source revision and asks for
confirmation before running `kamal deploy`.

Use `--allow-dirty` only for an intentional test deployment, `--verbose` for
detailed Kamal output, and `--yes` for deliberate non-interactive deployment.

## Local configuration and secrets

Setup creates two ignored files:

- `.kamal/deploy.env` contains installation-specific, non-secret settings.
- `.kamal/secrets` contains `SECRET_KEY_BASE`, `VAPID_PRIVATE_KEY`, and
  `VAPID_PUBLIC_KEY` and is created with permissions `0600`.

Back up `.kamal/secrets` in a password manager or deployment system. Replacing
these values invalidates user sessions and Web Push subscriptions. Setup keeps a
complete existing secrets file and refuses to overwrite an incomplete one.

The tracked `.kamal/deploy.env.example` and `.kamal/secrets.example` document
the formats for teams that provision these files through other tooling.

Supported deployment settings are:

- `DEPLOY_HOST` (required)
- `DEPLOY_SSH_USER` (default: `root`)
- `DEPLOY_STORAGE_PATH` (default: `/var/lib/kamal/bonfire/storage`)
- `DEPLOY_STORAGE_UID` (default: `1000`, the container's Rails user)
- `KAMAL_SERVICE` (default: `bonfire`)
- `KAMAL_IMAGE` (default: `bonfire`)
- `KAMAL_REGISTRY` (default: `localhost:5555`)
- `KAMAL_BUILDER_ARCH` (default: `amd64`)

Kamal Proxy terminates TLS and forwards requests to the application on port 80.
`DISABLE_SSL` prevents the application container from terminating TLS a second
time; it does not disable HTTPS at the public proxy.

The pre-deploy hook creates the persistent storage directory and assigns it to
`DEPLOY_STORAGE_UID`. The configured SSH user must be allowed to create that
directory and change its ownership.

## Safety and recovery

`bin/bonfire` does not configure DNS or firewall rules, print secrets, replace
existing secrets, or modify a server before confirmation. Re-running setup uses
the saved configuration and secrets, making an interrupted setup resumable.

All application state lives under the persistent storage path. Follow
`docs/self-hosting.md` for backup and restore details before risky upgrades.
