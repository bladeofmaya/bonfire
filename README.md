# Bonfire

Bonfire is a web-based chat application. It supports many of the features you'd
expect, including:

- Multiple rooms, with access controls
- Direct messages
- File attachments with previews
- Search
- Notifications (via Web Push)
- @mentions
- API, with support for bot integrations

## Running your own Bonfire instance

Bonfire's Docker image contains everything needed for a fully-functional,
single-machine deployment. This includes the web app, background jobs, caching,
file serving, and SSL. You can use our pre-built image at
`ghcr.io/bladeofmaya/bonfire:latest`, or build your own from this repo.

### Deploying with ONCE

The easiest way to self-host Bonfire is with [ONCE](https://github.com/basecamp/once).
It will guide you through the initial set up and then keep your instance up to date automatically.

If you don't already have `once` installed, run this on the machine you want to run Bonfire on:

```sh
curl https://get.once.com | sh
```

`once` will launch as soon as the install is finished.

Choose Bonfire from the list of applications, follow the instructions, and ONCE will take care of the rest.

If you prefer the command line to the dashboard, you can deploy directly:

```sh
once deploy ghcr.io/bladeofmaya/bonfire --host chat.example.com
```

### Deploying with Docker

If you'd rather run the Docker image yourself, you can read more about that in the [self-hosting guide](docs/self-hosting.md).

> [!TIP]
> When you start Bonfire for the first time, you'll be guided through a wizard to create an admin account.
> The email address that you enter for the admin account will be visible on the sign-in page, it's there so
> that people have someone to contact if they need help with their account. If that bothers you, put in any
> email address you want and create yourself a new admin account.

## Development

You are welcome - and encouraged - to modify Bonfire to your liking.
Please see our [development guide](docs/development.md) for how to get Bonfire set up for local development.

## Security

See [SECURITY.md](SECURITY.md) for how to report a vulnerability and a description of our trust model.
