## Development

### Setting up

Install and configure the development dependencies with:

```sh
bin/setup
```

This installs the system packages Bonfire needs, the correct Ruby version via
[mise](https://mise.jdx.dev), application gems, and development tooling. Docker,
Docker Compose, and Foreman must also be available locally.

### Running the application

Start Rails and the Redis development container with:

```sh
bin/dev
```

Open [http://bonfire.localhost:3021](http://bonfire.localhost:3021). The Redis
container binds only to `127.0.0.1:6321`; Bonfire uses SQLite and filesystem
uploads, so it needs no Postgres or MinIO containers.

Foreman reads `Procfile.dev` and supervises both processes. Stopping Foreman
also stops the attached Redis Compose process.

On first run, Bonfire guides you through creating the administrator account.

### Resetting local data

To return to the initial administrator setup:

```sh
bin/dev reset
```

After confirmation, this removes only local development state: the development
SQLite database, uploaded files, Redis container, logs, and temporary files. It
then prepares an empty database and starts the normal development processes.

For automation, use `bin/dev reset --yes`. To reset without starting Foreman,
use `bin/dev reset --yes --no-start`.

The reset command refuses to run when `RAILS_ENV` or `RACK_ENV` is production.
It does not read deployment configuration or contact a deployment server.

### Assigned local ports

| Hostname & Port | Postgres Port | Redis Port | MINIO Port | Notes |
|---|---|---|---|---|
| `bonfire.localhost:3021` | none | `6321:6379` | none | Custom Campfire clone |

### Web Push notifications

Campfire uses VAPID keys to send browser push notifications. To test Web Push
locally, generate a key pair with:

```sh
script/admin/generate-secrets
```

Export the generated `VAPID_PRIVATE_KEY` and `VAPID_PUBLIC_KEY` before starting
the development processes. The generated secret key base is not needed in
development.

### Running tests

Run unit and integration tests with:

```sh
bin/rails test
```

Run browser tests with:

```sh
bin/rails test:system
```

Before pushing changes, run style, security, and test checks with:

```sh
bin/ci
```

### Contributing

You are welcome and encouraged to modify Bonfire. Changes that also apply to
Campfire can be prepared on a branch based on `upstream/main`; see
`CONTRIBUTING.md` for the upstream contribution guidelines.
