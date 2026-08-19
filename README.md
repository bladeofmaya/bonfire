<p align="center">
  <img src="app/assets/images/bonfire-icon.png" alt="Bonfire" width="220">
</p>

# Bonfire

Bonfire is a self-hosted community chat for conversations, announcements, and
live streams. It gives a community one private installation, its own identity,
and direct ownership of its conversations and uploads.

Bonfire is based on [once-campfire](https://github.com/basecamp/once-campfire)
by 37signals and is developed independently while retaining selected upstream
fixes.

> [!IMPORTANT]
> Bonfire is usable but remains under active development. Expect occasional
> rough edges and changes between releases.

![Bonfire community chat](app/assets/images/bonfire-preview.png)

## Features

### Conversations and community

- Open and private channels, direct conversations, search, replies, reactions,
  file sharing, and rich-media previews
- Clear unread and mention indicators, channel ordering, and notification
  choices for each conversation
- Your own name, logo, colors, light or dark theme, and custom community emotes
- A welcoming signup page where members can read and accept your server rules
- Straightforward tools for inviting people, managing members, and handling
  unwanted behavior
- Bot accounts for bringing updates and useful community tools into channels

### Notifications

- Browser notifications for messages, mentions, direct conversations, and
  streams going live
- Email choices for missed mentions and pings, daily summaries, and streams
  going live—with one switch to turn all email off
- Optional signup emails for administrators when somebody joins the community
- Easy Postmark setup, with support for an existing SMTP mail provider too

### Private streaming

- A large stream player directly inside a channel, alongside chat, poster art,
  schedules and descriptions, viewer lists, and clear LIVE/OFFLINE status
- Private streams that follow the channel's membership, so the same people who
  can enter the channel can watch its stream
- Notifications when a stream goes live
- Support today for connecting your own RTMP or secure RTMPS streaming server
  through RTMP Homebrew
- Twitch, YouTube, and Kick integrations are in the works
- A re-streaming system for broadcasting to multiple destinations is also in
  the works

Bonfire controls access and the room experience; it does not ingest, proxy,
record, or restream video. See the [streaming guide](docs/streaming.md) for the
RTMP Homebrew contract and setup.

### Self-hosting

- One self-contained package designed to run on a single Linux server
- Conversations, settings, and uploads kept together in one folder you control
- Guided setup, updates, health checks, backups, and moves to a new server
- An installable web app that works on desktop and mobile

## Deploy on one server

Bonfire’s guided workflow expects a Linux server reachable over SSH, a domain
pointing to it, and Docker on the local machine. Start with:

```sh
bin/bonfire setup
```

The command creates private deployment configuration, generates installation
secrets, checks the target, shows the planned changes, and deploys with Kamal.
On first launch, Bonfire guides you through creating the installation’s first
administrator.

### Optional email delivery

Postmark is the recommended email provider. Configure it before a deployment:

```sh
bin/bonfire setup --configure-only
bin/bonfire mailserver setup \
  --provider postmark \
  --from "Bonfire <notifications@example.com>"
bin/bonfire mailserver status
bin/bonfire deploy
```

After deployment, verify real delivery to the installation’s first active
administrator:

```sh
bin/bonfire mailserver test
```

Provider credentials are stored in `.kamal/secrets`, are never printed by the
status command, and are not committed to Git. Generic SMTP is available with
`--provider smtp`. See [email notifications](docs/email-notifications.md) for
delivery policy, DNS authentication, and configuration details.

### Operations

| Command | Purpose |
| --- | --- |
| `bin/bonfire status` | Inspect local configuration and deployment health |
| `bin/bonfire deploy` | Deploy the current source and run pending migrations |
| `bin/bonfire console` | Open the production Rails console |
| `bin/bonfire kamal details` | Run an allowed Kamal operation with Bonfire’s configuration |
| `bin/bonfire migrate USER@HOST --dry-run` | Check a server migration without changing either server |
| `bin/bonfire migrate USER@HOST` | Move persistent storage and deployment to another server |

Run `bin/bonfire help` or `bin/bonfire mailserver help` for all supported
options. Back up `.kamal/secrets` securely; changing the generated application
or VAPID keys invalidates sessions or browser push subscriptions.

The [self-hosting guide](docs/self-hosting.md) covers manual Docker operation,
persistent storage, HTTPS, upgrades, backups, restores, and server migration.
You can use `ghcr.io/bladeofmaya/bonfire:latest` with an existing container
workflow or build the image yourself:

```sh
docker build -t bonfire .
```

## Develop locally

Install the required Ruby version, gems, and development dependencies:

```sh
bin/setup
```

Start Bonfire and its local Redis container:

```sh
bin/dev
```

Open [http://bonfire.localhost:3021](http://bonfire.localhost:3021) and complete
the first-run setup. Development uses SQLite and local file storage, so no
Postgres or object-storage service is required.

Reset local application data when you need a clean installation:

```sh
bin/dev reset
```

Run the test and project check suites with:

```sh
bin/rails test
bin/rails test:system
bin/ci
```

See the [development guide](docs/development.md) for Web Push setup, RTMP
Homebrew development, reset behavior, and test details.

## Documentation

- [Self-hosting and operations](docs/self-hosting.md)
- [Email notifications](docs/email-notifications.md)
- [Private room streaming](docs/streaming.md)
- [Development](docs/development.md)
- [UI style guide](docs/ui-style-guide.md)
- [CSS architecture](docs/css-architecture.md)
- [Component contracts](docs/component-contracts.md)
- [Architecture decisions](docs/architecture/decisions/0001-hybrid-view-components.md)

## Contributing

Bug fixes, focused improvements, and thoughtful product ideas are welcome.
Keep changes scoped, tested, and documented, and preserve Bonfire’s room
privacy and server-side authorization boundaries. See
[CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidance.

## Security

Please report security issues privately by following
[SECURITY.md](SECURITY.md).
