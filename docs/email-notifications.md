## Email notifications

Email is globally opt-in for an installation and individually opt-in for every
user. It is deliberately independent from Web Push and per-room involvement.
Users control the master switch, mention/ping delivery, daily summaries, local
delivery hour, and time zone under **Profile → Notifications**.

### Delivery policy

- Mention mail covers explicit Action Text mentions in shared rooms and every
  message from another participant in a direct conversation.
- A five-minute delay gives a user time to reconnect. The job then rechecks
  that the user is active, still belongs to the room, is
  disconnected from it, and still has both the master and mention switches on.
- Only message creation schedules mention mail. Edits do not send mail,
  duplicate mentions produce one delivery, and a deleted message or user is
  discarded through Active Job deserialization handling. Bot-authored messages
  follow the same recipient rules; bots never receive email.
- Quiet hours are not a separate mode: mention mail observes its five-minute
  grace period, while summaries are delivered only at the chosen local hour.
- Daily summaries contain messages from the previous day in the user's time
  zone, limited to non-stream channels that are still accessible and unread at
  delivery time. Each channel shows its five newest qualifying messages and a
  link labeled with the full new-message count. A scheduler runs hourly and
  queues each user's summary at their selected local hour.
- Delivery rows have unique message/period keys. Jobs recheck those rows under
  a lock, making retries idempotent. Successful and empty deliveries emit the
  `email_notification.delivered` Active Support event with non-personal mode
  metadata.

### SMTP configuration

Email is disabled unless `EMAIL_NOTIFICATIONS_ENABLED=true`. When enabled,
production startup requires:

- `MAILER_HOST`: canonical public Bonfire hostname used in email links
- `SMTP_ADDRESS` and `SMTP_PORT`: SMTP server and port
- `SMTP_USERNAME` and `SMTP_PASSWORD`: SMTP credentials

Optional variables are `EMAIL_FROM` (default `Bonfire
<notifications@localhost>`), `MAILER_PROTOCOL` (default `https`),
`SMTP_AUTHENTICATION` (default `plain`), and `SMTP_STARTTLS` (default `true`).
The bundled process supervisor runs Resque workers and Resque Scheduler; both
must remain running for delayed mentions and summaries.

Before enabling production delivery, authorize the sending host in the
domain's SPF record, configure DKIM signing with the SMTP provider, and publish
a DMARC policy with aggregate reporting. Start with a monitoring policy, check
alignment of the visible From domain with SPF or DKIM, and only then move to
quarantine or reject. Never commit SMTP credentials.

Mailer previews are available in development at `/rails/mailers`, including
mention and daily-summary examples. Both HTML and plain-text versions contain
canonical conversation links and a direct link to notification settings.
