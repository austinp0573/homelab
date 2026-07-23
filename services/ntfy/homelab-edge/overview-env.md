# ntfy settings

This is the settings reference for this stack. It covers the Compose `.env` file, the `server.yml` file, and the variables used by the helper scripts.

The stack is pinned to ntfy `v2.14.0`. Check the upstream ntfy config reference before using options added in a newer release.

## current defaults

- localhost bind on port 2586
- public HTTPS URL behind haproxy
- SQLite for messages and auth
- seven days of message history
- 10 MiB maximum attachment file
- 100 MiB total attachment cache
- 24-hour attachment expiry
- deny by default authentication
- no signups

## compose environment

Put these in `.env`. They control Docker Compose and the helper scripts. They do not automatically change `config/server.yml`.

`COMPOSE_PROJECT_NAME`

Compose project name. Default: `ntfy`. Change it only when multiple copies run on one host.

`CONTAINER_NAME`

Container name. Default: `ntfy`. Keep it unique on the host.

`RESTART_POLICY`

Container restart policy. Default: `unless-stopped`. Use `no` for a temporary manual test.

`NTFY_IMAGE`

Container image. Default: `binwiederhier/ntfy:v2.14.0`. Keep a version tag. Do not use `latest`.

`TZ`

Container timezone. Default: `UTC`. This affects timestamps in logs and scheduled operations.

`BASE_URL`

Public HTTPS URL. Default: `https://ntfy.example.com`. Keep this identical to `base-url` in `config/server.yml`. Scripts print it, but ntfy reads the YAML value.

`HOST_BIND`

Host address for the published container port. Default: `127.0.0.1`.

Use `127.0.0.1` when haproxy runs on the same host. Use `0.0.0.0` only when another host, such as the edge VPS over Headscale, needs to reach ntfy. Firewall the port when using `0.0.0.0`.

`HOST_PORT`

Host port mapped to ntfy's container port 80. Default: `2586`.

`DATA_DIR`

Host directory for `auth.db` and `webpush.db`. Default: `./data`. Back this up if users, tokens, and browser push subscriptions matter.

`CACHE_DIR`

Host directory for the SQLite message cache and attachments. Default: `./cache`. This can be deleted to clear retained messages and attachments, but ntfy must be stopped first.

`NTFY_ADMIN_USER`

Admin username used by the bootstrap and reset scripts. Default: `admin`. Change it before the first bootstrap if desired.

`COMPOSE_CMD`

Optional helper-script override. Default: `nerdctl compose`. Set it to `docker compose` on a Docker host.

## password and token files

`secrets/admin-password.txt`

Optional one-line password used by the admin bootstrap and reset scripts. It is ignored by git. If it does not exist, the scripts prompt for a password.

`secrets/<topic>-token.txt`

Optional local note after creating a publisher token. ntfy does not read this file. The publisher host needs the real token in its own secret store.

`NTFY_PASSWORD`

The helper scripts pass this into a one-time `ntfy user` command inside the container. Do not put it in `.env`.

## server.yml

Use `config/server.yml` for ntfy server settings. ntfy accepts dash or underscore names. This stack uses dash names.

ntfy also accepts server settings as `NTFY_` environment variables. Convert the YAML key to upper snake case, such as `cache-duration` to `NTFY_CACHE_DURATION`. This Compose file does not forward arbitrary `.env` values into the container, so add an explicit Compose `environment` entry when using that method.

### network and TLS

`base-url`

The public URL clients use. Required for attachments, email links, and iOS upstream push. This stack uses the HTTPS URL served by haproxy.

`listen-http`

HTTP listen address inside the container. This stack uses `:80`. Set it to `-` only when ntfy serves HTTPS itself.

`listen-https`

HTTPS listen address when ntfy terminates TLS itself. Leave unset when haproxy terminates TLS.

`listen-unix`

Unix socket path. Useful for native installs. Not useful for this container stack.

`listen-unix-mode`

Permissions for `listen-unix`. Use a restrictive mode such as `0700` when using a socket.

`key-file`

Private key for `listen-https`. Do not set it behind haproxy.

`cert-file`

Certificate for `listen-https`. Do not set it behind haproxy.

`behind-proxy`

Trust proxy forwarding headers for visitor address handling. This stack sets it to `true` because haproxy is in front.

`proxy-forwarded-header`

Forwarded client IP header. Default is `X-Forwarded-For`. Change only when the proxy uses another header.

`proxy-trusted-hosts`

Trusted proxies removed from a forwarded address chain. Set this when more than one proxy sits in front of ntfy.

### storage and database

`database-url`

PostgreSQL connection string. It replaces the SQLite cache, auth, and web push databases. Do not set it with `cache-file`, `auth-file`, or `web-push-file`.

`cache-file`

SQLite message cache path. This stack uses `/var/cache/ntfy/cache.db`.

`cache-duration`

Message history duration. This stack uses `7d`. Set `0` to disable message history.

`cache-startup-queries`

SQLite queries run when the message cache opens. Useful for database tuning. Leave unset for this small stack.

`cache-batch-size`

Number of messages queued before a batch database write. Leave at `0` for synchronous writes.

`cache-batch-timeout`

Maximum wait before a queued batch is written. Only useful with `cache-batch-size` on a busy server.

`auth-file`

SQLite user, ACL, and token database. This stack uses `/var/lib/ntfy/auth.db`.

`auth-default-access`

Fallback access when no ACL matches. This stack uses `deny-all`. Other values are `read-write`, `read-only`, and `write-only`.

`auth-startup-queries`

SQLite queries run when the auth database opens. Leave unset unless tuning SQLite.

`auth-users`

Declarative users in `username:password-hash:role` form. Do not use it in this stack. The helper scripts write users to `auth.db`.

`auth-access`

Declarative ACLs in `username:topic-pattern:access` form. Do not use it with the helper-script managed publisher users.

`auth-tokens`

Declarative access tokens in `username:token:label` form. Do not put tokens in tracked YAML.

### attachments and message templates

`attachment-cache-dir`

Directory or S3 URL used for uploaded files. This stack uses `/var/cache/ntfy/attachments`.

`attachment-total-size-limit`

Maximum size of the attachment cache. This stack uses `100M`.

`attachment-file-size-limit`

Maximum size of one attachment. This stack uses `10M`.

`attachment-expiry-duration`

Attachment retention period. This stack uses `24h`.

`visitor-attachment-total-size-limit`

Maximum attachment storage used by one visitor. This stack uses `25M`.

`visitor-attachment-daily-bandwidth-limit`

Maximum attachment upload and download bandwidth for one visitor per day. This stack uses `100M`.

`template-dir`

Directory of custom YAML message templates. Leave unset unless a publisher sends structured JSON and needs server-side formatting.

### delivery integrations

`firebase-key-file`

Firebase service account key for Android push. Leave unset unless managing an Android push integration.

`smtp-sender-addr`

Outgoing SMTP server address. Set it with the other `smtp-sender-*` values to allow publishers to request email delivery.

`smtp-sender-from`

Sender address for outgoing SMTP notifications.

`smtp-sender-user`

SMTP username. Store it in the ignored `server.yml`, not the tracked example.

`smtp-sender-pass`

SMTP password. Treat it as a secret.

`smtp-server-listen`

Address for ntfy's incoming SMTP server. Leave unset unless email-to-topic publishing is required.

`smtp-server-domain`

Email domain accepted by the incoming SMTP server.

`smtp-server-addr-prefix`

Required prefix for incoming SMTP recipient addresses. Use one when enabling incoming SMTP to reduce accidental mail delivery.

`web-push-public-key`

VAPID public key for browser push. Generate it with `./scripts/webpush-keys.sh`.

`web-push-private-key`

VAPID private key for browser push. Keep it only in the ignored `config/server.yml`.

`web-push-file`

SQLite database for browser subscriptions. This stack uses `/var/lib/ntfy/webpush.db` when web push is enabled.

`web-push-email-address`

Contact address sent to the browser push provider.

`web-push-startup-queries`

SQLite queries run when the web push database opens. Leave unset unless tuning it.

`web-push-expiry-warning-duration`

Age at which unused browser subscriptions receive a warning. Default: `55d`.

`web-push-expiry-duration`

Age at which unused browser subscriptions expire. Default: `60d`.

`twilio-account`

Twilio account ID for voice call delivery. Leave unset unless using `X-Call`.

`twilio-auth-token`

Twilio API token. Treat it as a secret.

`twilio-phone-number`

Twilio phone number used for calls.

`twilio-verify-service`

Twilio Verify service ID.

`twilio-call-format`

Custom TwiML for voice calls. Leave unset unless the default call message is unsuitable.

`upstream-base-url`

Firebase and APNS connected ntfy server used for timely iOS notifications. Set it to `https://ntfy.sh` when iOS delivery matters. The upstream receives only a poll request, not the message body.

`upstream-access-token`

Token for the upstream ntfy server when its rate limit requires one. Keep it in ignored configuration.

### server behavior

`keepalive-interval`

Interval for keepalive messages to subscribed clients. Keep it below 77 seconds for Android. Default: `45s`.

`manager-interval`

Interval for cleanup and manager work. Default: `1m`.

`disallowed-topics`

Additional topic names that publishers cannot use. Use it to reserve local route names.

`web-root`

Path where the web app is served. Use `/` for normal operation. Set `disable` to turn off the web app.

`enable-signup`

Allows new account registration. Leave `false` for this private service.

`enable-login`

Allows web and API login. This stack sets it to `true`.

`require-login`

Redirects web users to login and blocks unauthenticated web app access. This stack sets it to `true`.

`enable-reservations`

Allows topic reservations for account tiers. Leave `false` for this simple auth setup.

`message-size-limit`

Maximum message body size. Default: `4k`. Keep it small when using mobile push.

`message-delay-limit`

Maximum permitted delayed-message interval. Default: `3d`.

`global-topic-limit`

Maximum number of topics the server accepts. Default: `15000`. Lower it only for a tightly controlled public service.

`visitor-subscription-limit`

Maximum subscriptions per visitor. Default: `30`.

`visitor-request-limit-burst`

Initial request rate-limit bucket per visitor. Default: `60`.

`visitor-request-limit-replenish`

Request rate-limit refill interval. Default: `5s`.

`visitor-request-limit-exempt-hosts`

Comma-separated hosts or CIDRs exempt from visitor request limits. Leave empty unless a trusted automation needs it.

`visitor-message-daily-limit`

Maximum messages per visitor per UTC day. Default: `0`, which leaves the request limit as the effective limit.

`visitor-email-limit-burst`

Initial outgoing-email rate-limit bucket per visitor. Default: `16`.

`visitor-email-limit-replenish`

Outgoing-email rate-limit refill interval. Default: `1h`.

`visitor-prefix-bits-ipv4`

IPv4 prefix size used to group visitors for rate limiting. Default: `32`, one address per visitor.

`visitor-prefix-bits-ipv6`

IPv6 prefix size used to group visitors for rate limiting. Default: `64`, one subnet per visitor.

`visitor-subscriber-rate-limiting`

Uses UnifiedPush subscribers as the rate-limit visitor for UnifiedPush topics. Leave `false` unless running UnifiedPush.

### observability, billing, and logs

`stripe-secret-key`

Stripe API key. Enabling it adds payment features to the web app. Do not use it for this private setup.

`stripe-webhook-key`

Stripe webhook verification key. Required with Stripe billing.

`billing-contact`

Contact address shown in the billing dialog. Only useful with Stripe.

`enable-metrics`

Exposes Prometheus metrics at `/metrics`. Treat metrics as sensitive and protect them in haproxy.

`metrics-listen-http`

Dedicated metrics listener address. It also enables metrics. Bind it privately if used.

`profile-listen-http`

Dedicated Go profiling listener. Enable only while investigating a performance issue and bind it privately.

`log-level`

Default log level. Values: `trace`, `debug`, `info`, `warn`, or `error`. Keep `info` for normal operation.

`log-level-overrides`

Targeted debug rules. They add overhead and should be temporary.

`log-format`

Log format. Values: `text` or `json`. Keep `text` for manual logs. Use `json` when a log collector parses them.

`log-file`

Optional log file path. Leave unset in this container stack so logs go to the container runtime.

## changing settings

1. Edit the ignored `config/server.yml`.
2. Run `./scripts/up.sh` after a normal change.
3. Use `nerdctl compose up -d --force-recreate` after web push or container-level changes.
4. Run `./scripts/smoke.sh`.

Do not put passwords, access tokens, SMTP credentials, Twilio credentials, Stripe keys, or VAPID private keys in the tracked example file.
