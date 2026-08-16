# Room streaming

Bonfire embeds an RTMP Homebrew player for explicitly configured rooms.
Bonfire does not ingest, proxy, record, or restream media. Room membership is
the viewer authorization boundary; installation administrators configure a
stream but receive no implicit membership or viewing access.

## Configuration

Configure these values as environment variables or under the
`rtmp_homebrew` Rails credential namespace:

| Environment variable | Credential key | Purpose |
| --- | --- | --- |
| `RTMP_HOMEBREW_PRIVATE_KEY` | `private_key` | PEM-encoded P-256 signing key. A literal `\\n` is accepted in environment values. |
| `RTMP_HOMEBREW_KEY_ID` | `key_id` | Stable identifier published as the JWT/JWK `kid`. |
| `RTMP_HOMEBREW_ISSUER` | `issuer` | Stable HTTPS Bonfire issuer expected by RTMP Homebrew. |
| `RTMP_HOMEBREW_AUDIENCE` | `audience` | JWT audience; defaults to `rtmp-homebrew`. |
| `RTMP_HOMEBREW_ALLOWED_PLAYER_ORIGINS` | `allowed_player_origins` | Comma-separated exact HTTPS player origins. Credentials accept an array. |
| `RTMP_HOMEBREW_PREVIOUS_JWKS` | `previous_jwks` | Public JWKs retained during an operator-controlled key-rotation overlap. Never include private `d`; Bonfire strips it defensively. |
| `RTMP_HOMEBREW_EVENT_SECRET` | `event_secret` | High-entropy shared secret used only to authenticate publisher lifecycle callbacks. |

If any signing configuration is present, Bonfire validates the complete
configuration during startup without logging key material. An unconfigured
installation can run normally, but cannot enable a valid stream or issue a
grant.

Development defaults the allowed player origin to
`https://stream.localhost:8443`. Set
`RTMP_HOMEBREW_ALLOWED_PLAYER_ORIGINS` before starting Bonfire to override it.
When RTMP Homebrew is checked out next to Bonfire, `bin/dev` also loads its
generated `.local/bonfire-streaming.env` automatically; explicit environment
values remain authoritative.

Generate and store the private key outside the repository. RTMP Homebrew reads
public verification keys from:

```text
/.well-known/rtmp-homebrew-jwks.json
```

For rotation, deploy the new private key and `kid` while placing the previous
public JWK in `RTMP_HOMEBREW_PREVIOUS_JWKS`. Keep it published for longer than
the configured operational overlap and the 60-second token lifetime, then
remove it. Never put an old private key in that value.

## RTMP Homebrew dependency

Production playback requires RTMP Homebrew's embeddable, version-1
`postMessage` player and JWT/JWKS authentication. Its player response must set
`frame-ancestors` to the exact Bonfire origin. Development Basic credentials
must remain in RTMP Homebrew and are never copied into Bonfire.

## Publisher lifecycle events

RTMP Homebrew is authoritative for whether a publisher is currently present.
It posts `stream.started`, `stream.heartbeat`, and `stream.stopped` events to
`POST /streaming/events`. A heartbeat must be sent every 15 seconds while the
publisher is present. Bonfire expires the LIVE badge 45 seconds after the last
heartbeat, so a missed stop event or service failure cannot leave it displayed
indefinitely.

Each JSON event has this shape:

```json
{
  "version": 1,
  "event_id": "unique-event-id",
  "type": "stream.started",
  "stream_path": "live",
  "session_id": "stable-for-one-publisher-session",
  "occurred_at": "2026-08-15T18:00:00.000Z"
}
```

Set `X-Bonfire-Timestamp` to the current Unix timestamp and
`X-Bonfire-Signature` to the lowercase hexadecimal HMAC-SHA256 of
`<timestamp>.<raw JSON body>` using `RTMP_HOMEBREW_EVENT_SECRET`. Bonfire
rejects timestamps and event occurrence times outside a two-minute window.
Event IDs make retries idempotent, while session IDs ensure that a delayed stop
from an old publisher cannot stop a newer publisher.

The shared secret must be generated and stored outside both repositories. Do
not reuse a playback, publishing, cookie, or JWT-signing secret.

## Local fixture protocol

Bonfire's browser tests simulate the reciprocal player messages without a
media server. The player must send `player.ready`, `player.state`, and optional
`token.refresh_requested` messages with source `rtmp-homebrew`, version `1`,
and exact origin/source checks. Bonfire responds with `playback.authorize` to
the configured origin. Tokens remain in memory and never enter HTML, URLs,
Turbo attributes, logs, analytics, or browser storage.

## Joint smoke-test checklist

Before production rollout, test with the final RTMP Homebrew build:

- Configure a room, title, poster, HTTPS player URL, and exact
  stream path. Confirm non-administrators cannot edit these values.
- Confirm a selected active member can chat and play the stream, while a
  non-member, removed member, bot, banned user, and deactivated user cannot.
- Confirm JWKS contains only current/overlap public keys and MediaMTX accepts a
  read grant only for the configured path. Verify publish/API/metrics access is
  rejected.
- Start and stop OBS. Verify connecting, live, offline, and bounded reconnect
  states, muted autoplay, manual pause, fullscreen, and picture-in-picture.
- Leave the room open past several 30-second refreshes, then remove membership.
  Confirm refresh stops and playback expires within 60 seconds.
- Navigate repeatedly between rooms and use back/forward. Confirm old players,
  requests, listeners, and timers are torn down.
- Inspect HTML, request URLs, browser storage, analytics, Rails logs, and proxy
  logs for playback tokens or private-key material; none may appear.
- Verify CSP allows only the configured player origin and the player permits
  framing only from the configured Bonfire origin.
- At desktop and mobile widths, verify the 16:9 player remains above chat,
  never covers the composer, and preserves space while offline.
- Re-test ordinary messages, optimistic sends, edits/deletes, boosts, unread
  state, reconnect refreshes, room-list broadcasts, closed-room privacy,
  notification controls, and mobile navigation.
