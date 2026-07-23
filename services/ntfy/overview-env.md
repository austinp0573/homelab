# ntfy env

homelab-edge stack (`ntfy/homelab-edge/`). pin `v2.14.0`. `.env` does **not** auto-feed `server.yml` — compose only passes `TZ`. leave `homelab-edge/overview-env.md` as the older prose copy.

## compose `.env`

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `ntfy` | Compose project for the edge ntfy container and its bind mounts. Keep stable so `./data` and `./cache` stay obviously tied to this stack. Renaming does not move files but breaks script assumptions and your own muscle memory. One project per ntfy instance — do not dual-run two writables against the same auth.db. |
| `CONTAINER_NAME` | `ntfy` | Fixed container name for logs, exec, and HAProxy mental mapping. Not magical DNS for clients; clients use `BASE_URL`. Renaming mid-life confuses `nerdctl logs` habits more than it breaks the app. Keep unique on the edge VPS. |
| `RESTART_POLICY` | `unless-stopped` | Notification bus should return after reboot without hand-holding. Explicit stop stays down — use that during cache/auth surgery. `always` is unnecessary; `no` means silent alert blackholes after reboot. I leave it unless-stopped so overnight jobs keep paging; only pin `no` on a throwaway test container. |
| `NTFY_IMAGE` | `binwiederhier/ntfy:v2.14.0` | Pinned server image — do not use `latest` on a box that pages you. Upgrades can change auth/cache semantics; read release notes and snapshot `data/` + `cache/`. Scripts and docs in this tree assume this pin generation. Record the pin in the edge runbook so a panicked recreate does not silently float. |
| `TZ` | `UTC` | Only compose-injected env into the container besides image defaults. Affects log timestamps and any schedule-ish behavior. `server.yml` is not auto-templated from `.env` — set timezone here and still edit yaml for real config. Mismatch with host TZ confuses correlating journald and ntfy logs. |
| `BASE_URL` | `https://ntfy.example.com` | Public URL used by scripts/print helpers. **Must match** `server.yml` `base-url` or attachments, email callbacks, and iOS upstream behavior lie to you. Changing one file and not the other is the classic broken-deep-link bug. Use the real HTTPS name clients see. |
| `HOST_BIND` | `127.0.0.1` | Publish bind. Same-host HAProxy ⇒ loopback. Home lab reached over Headscale from edge ⇒ often `0.0.0.0` plus host firewall/nftables allowing only the tailnet. Wrong bind is either "HAProxy 502" or "world-readable ntfy". Pick for topology, not habit. |
| `HOST_PORT` | `2586` | Host port → container `:80`. HAProxy backend should target this. Non-80 host port avoids colliding with other loopback HTTP. Changing it means updating every proxy snippet and smoke script. |
| `DATA_DIR` | `./data` | Host dir for `auth.db`, `webpush.db`, and durable state. Lose this and users/tokens/ACLs are gone. Stop ntfy before copying or restoring. Permissions must allow the container user to write sqlite. |
| `CACHE_DIR` | `./cache` | Message cache DB plus attachments. Stop ntfy before deleting or you corrupt sqlite. Wiping cache loses history within `cache-duration` but not auth. Disk growth here is usually attachments — watch limits in yaml. |
| `NTFY_ADMIN_USER` | `admin` | Username bootstrap/reset scripts create or reset. Not read by the server from `.env` at runtime — scripts only. Changing it does not rename an existing DB user automatically. Pair with password via secrets/prompt, never commit the password. |
| `COMPOSE_CMD` | `nerdctl compose` | Optional script override for compose on this host. Keep consistent with edge tooling. Wrong binary breaks `up.sh` before ntfy itself is at fault. Leave default if that is what the VPS uses. |

## secrets / scripts

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `secrets/admin-password.txt` | `<secret>` | Optional file bootstrap scripts read for the admin password; otherwise they prompt. Keep out of git and out of `.env`. Rotating means script reset + updating every client that used the old password. Empty file is worse than missing — do not leave a blank. |
| `secrets/<topic>-token.txt` | `<secret>` | Local operator note of topic tokens you created. ntfy does **not** read these files at runtime — auth lives in `auth.db`. Useful so you do not paste tokens into chat logs. Treat as secrets anyway; loss means regenerate tokens in ntfy. |
| `NTFY_PASSWORD` | `<secret>` | Script-only one-shot env for non-interactive bootstrap. **Never** put this in committed `.env`. Prefer file or prompt. Leaking it in process lists is why files exist. |

## `server.yml` — this stack's set values

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `base-url` | `https://ntfy.example.com` | Canonical public HTTPS URL. Required for attachment links, email flows, and iOS upstream poll behavior to generate correct URLs. Must match `.env` `BASE_URL` and the HAProxy/TLS name. Internal `http://127.0.0.1:2586` is not a valid base-url for clients. |
| `listen-http` | `:80` | In-container listen address. Behind HAProxy this stays HTTP on `:80`. Set to `-` only if ntfy itself terminates TLS via `listen-https`. Changing without updating the compose port map breaks health checks. |
| `behind-proxy` | `true` | Trust forwarded headers from HAProxy for client IP and scheme. Required for rate limits and logs to reflect real clients. `false` behind a proxy makes everyone look like the proxy IP. Do not expose ntfy directly to the internet with this true and no trusted proxy. |
| `cache-file` | `/var/cache/ntfy/cache.db` | Path inside the container for the message cache sqlite (mapped via `CACHE_DIR`). Do not point at the auth file path. Delete only while stopped. Corruption here usually means wipe cache, not auth. |
| `cache-duration` | `7d` | How long messages remain fetchable. `0` disables history — fine for pure push, painful for late subscribers. Longer retains more disk in cache/attachments. Tune to how late you read phone notifications. |
| `auth-file` | `/var/lib/ntfy/auth.db` | Users, ACLs, tokens DB under `DATA_DIR`. Manage via scripts (`ntfy user` / helpers), not by hand-editing sqlite. Restore from backup only while stopped. This is the crown jewel beside TLS certs. |
| `auth-default-access` | `deny-all` | Default ACL when no topic rule matches. `deny-all` is correct for a private lab. `read-write` is how topics become public. Other values (`read-only` / `write-only`) are situational — know what you are opening. |
| `enable-signup` | `false` | Disables self-service account creation. Leave false on a private server. True plus public exposure is spam accounts. Admins are created by scripts instead. |
| `enable-login` | `true` | Allows password login to the web UI/API. Needed if you use users rather than only tokens. False locks you into token-only workflows. Pair with `require-login`. |
| `require-login` | `true` | Rejects anonymous publish/subscribe. Matches `deny-all` philosophy. Turning false while default-access is open is catastrophic. Keep true for homelab edge. |
| `enable-reservations` | `false` | Topic reservation feature off unless you need it. Reservations add auth complexity for little gain on a small private server. Enable only with a clear ACL plan. If you turn it on, document who may reserve which prefixes before the first fight. |
| `attachment-cache-dir` | `/var/cache/ntfy/attachments` | On-disk attachment blobs under the cache mount. Grows independently of message row retention until expiry. Wipe only while stopped. Monitor disk on busy topics. |
| `attachment-total-size-limit` | `100M` | Global cap for attachment storage. Hitting it rejects new attachments while messages may still work. Raise only with disk headroom. Not a per-user quota by itself. |
| `attachment-file-size-limit` | `10M` | Per-file upload cap. Stops accidental huge dumps. Clients see failures when over. Align with reverse-proxy body size limits. |
| `attachment-expiry-duration` | `24h` | When attachment bytes expire from disk. Shorter saves disk; longer lets slow readers fetch files. Independent of `cache-duration` but related in practice. I keep this short on the edge VPS where disk is the scarce resource. |
| `visitor-attachment-total-size-limit` | `25M` | Per-visitor attachment budget. Limits abuse from a single IP/user under proxy-correct IPs. Too low frustrates legit bulk; too high weakens DoS resistance. Depends on `behind-proxy` being correct. |
| `visitor-attachment-daily-bandwidth-limit` | `100M` | Per-visitor daily attachment bandwidth. Another abuse brake. Resets on visitor accounting intervals. Watch logs when clients complain uploads fail mid-day. |

## `server.yml` — optional / unused here

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `listen-https` | unset | ntfy-terminates-TLS path. Leave unset behind HAProxy. Enabling means you also need cert files and a different port map. Dual TLS termination is a good way to debug certificates forever. |
| `listen-unix` / `listen-unix-mode` | unset | Unix socket listen for native installs / special proxies. Unused in this compose HTTP publish model. Mode bits matter if you enable it. Prefer TCP behind HAProxy here. |
| `key-file` / `cert-file` | unset | TLS materials for `listen-https`. Required only if ntfy serves HTTPS itself. Keep permissions tight. Prefer edge HAProxy certs in this design. |
| `proxy-forwarded-header` | `X-Forwarded-For` | Which header supplies client IPs when `behind-proxy` is true. Must match what HAProxy sends. Wrong header breaks visitor limits and ban logic. Rarely change unless your proxy uses Forwarded. |
| `proxy-trusted-hosts` | unset | Restrict which proxy IPs are trusted for forwards. Set when more than one hop can hit ntfy. Unset behind a single local HAProxy is common. Too broad re-opens IP spoofing. |
| `database-url` | unset | Postgres URL replacing sqlite cache/auth/webpush. Do not mix Postgres mode with the file-based knobs casually. Migration is a project, not a toggle. Leave unset for this sqlite lab layout. |
| `cache-startup-queries` | unset | Arbitrary sqlite PRAGMAs/statements at cache open. Power tool for tuning; easy to brick startup. Keep unset unless you are chasing a known sqlite issue. If you must set it, keep the statements in the private notes, not tribal memory. |
| `cache-batch-size` | `0` | `0` means sync writes (safer, slower). Batching improves throughput at durability risk on power loss. Only raise when you understand the trade. Homelab notification volume almost never needs batching; leave the safe default. |
| `cache-batch-timeout` | unset | Flush timer when batching is enabled. Ignored while batch size is 0. Too long increases loss window. Tune with batch size, not alone. |
| `auth-startup-queries` | unset | Same idea as cache startup queries for `auth.db`. Dangerous if wrong. Leave unset operationally. Prefer fixing host disk/sqlite issues over clever PRAGMAs in yaml. |
| `auth-users` / `auth-access` / `auth-tokens` | unset | Static yaml auth — avoid. Use scripts → `auth.db` so runtime ACL changes do not require yaml edits. Duplicating users in yaml and DB is chaos. Yaml static auth also drifts from what bootstrap scripts believe is source of truth. |
| `template-dir` | unset | Custom notification templates directory. Only when you brand messages. Wrong templates break formatting. Default templates are fine for lab. |
| `web-push-public-key` / `private-key` | `<secret>` | VAPID keys after `webpush-keys.sh`. Required for browser web push. Treat private key as secret; rotating breaks existing subscriptions. Force-recreate container after enabling. |
| `web-push-file` | `/var/lib/ntfy/webpush.db` | Subscription DB when web push is enabled (under data mount). Back up with auth if push matters. Delete only while stopped. Losing this DB is why browsers mysteriously stop getting pushes after a volume oops. |
| `web-push-email-address` | unset | Contact email VAPID/push providers expect. Use a real mailbox you read. Missing it can block enabling push. Not your SMTP from-address by itself. |
| `web-push-startup-queries` | unset | Sqlite tuning for webpush DB. Leave unset unless needed. Same caution as other startup-query knobs: easy to brick boot. I only touch this when a specific webpush sqlite lock shows up in logs. |
| `web-push-expiry-warning-duration` | `55d` | When to warn about subscription expiry. Align with how you re-subscribe browsers. Too short noisily warns; too long surprises with dead push. Wire any warning path to something you actually read, or the knob is theater. |
| `web-push-expiry-duration` | `60d` | Hard expiry for web push subs. Browsers need refresh before this. Coordinate with warning duration. Document the re-subscribe ritual next to this number for future-you on iOS/Android. |
| `firebase-key-file` | unset | FCM credentials for Android Firebase push path. Unused if you rely on other Android mechanisms. Keep secret if set. JSON key files are `<secret>` — mount them, do not commit them. |
| `smtp-sender-addr` / `from` / `user` / `pass` | unset / `<secret>` | Outgoing SMTP for email notifications. Password is `<secret>`. Misconfig fails email quietly from the user's POV. Prefer ntfy push when you can. |
| `smtp-server-listen` / `domain` / `addr-prefix` | unset | Inbound email-to-topic gateway. Powerful and spam-attracting if exposed. Leave unset unless you knowingly want mail → topic. If enabled, firewall the SMTP listener like any inbound MX-ish service. |
| `twilio-account` / `auth-token` / `phone-number` / `verify-service` / `call-format` | unset / `<secret>` | Twilio bits for `X-Call` voice. Auth token is `<secret>`. Costs real money — do not enable casually. Test with a tiny budget alert first; call storms are expensive. |
| `upstream-base-url` | often `https://ntfy.sh` | Upstream for timely iOS notifications (poll/control plane flavor — not your message bodies' privacy boundary to ignore). Set deliberately. Wrong upstream breaks iOS timeliness. Remember upstream helps wakeups; your topic ACLs on this server still govern who can publish locally. |
| `upstream-access-token` | `<secret>` | Token if upstream rate-limits you. Keep secret. Only when using upstream features that need it. Rotate if it ever lands in a pastebin or CI log. |
| `keepalive-interval` | `45s` | SSE/keepalive cadence. Keep under ~77s for Android connection expectations. Too aggressive wastes battery/CPU; too slow drops connections. If mobile clients flap, check proxies idle timeouts before blaming this alone. |
| `manager-interval` | `1m` | Internal manager loop interval. Rarely needs tuning. Lower increases wakeups. Leave default unless chasing a bug. |
| `disallowed-topics` | unset | Topic names you refuse (reserving system names). Use to block obvious footguns. Over-block frustrates clients. Put internal/system names here before someone automates into them. |
| `web-root` | `/` | Web app mount path; `disable` turns off the web UI. API can remain. Useful if you want API-only. Disabling the UI does not disable publish API — lock that down with auth still. |
| `message-size-limit` | `4k` | Max message body size. Raise carefully — everything stores and fans out. Clients fail when over. Big JSON dumps belong in attachments or elsewhere, not 4k bodies forever. |
| `message-delay-limit` | `3d` | Max schedule/delay horizon for delayed delivery. Longer means more bookkeeping. Keep sane for lab use. Delayed messages still consume cache/accounting — do not treat delay as free storage. |
| `global-topic-limit` | `15000` | Upper bound on topics. Protection against runaway automation. Unlikely to hit in homelab; still leave as a guardrail. If automation creates topics per host per check, watch this before you hit the ceiling. |
| `visitor-subscription-limit` | `30` | Max subscriptions per visitor. Stops subscription spam. Raise if a dashboard legitimately needs more. UnifiedPush clients can look like many subscriptions; raise knowingly, not blindly. |
| `visitor-request-limit-burst` | `60` | Burst token bucket for requests. Too low breaks busy pollers; too high weakens DoS protection. Depends on correct client IPs. After changing it, retest Gatus/ntfy publishers so monitors do not self-DoS. |
| `visitor-request-limit-replenish` | `5s` | Replenish interval for the request bucket. Tune with burst. Exempt monitoring IPs if they trip it. Faster replenish softens burst; slower replenish is harsher under scrapers. |
| `visitor-request-limit-exempt-hosts` | unset | CIDRs/hosts exempt from request limits. Put your monitor scrapers here if needed. Over-broad exemptions gut the limiter. Prefer exact monitor IPs over whole RFC1918 if the proxy sees real sources. |
| `visitor-message-daily-limit` | `0` | `0` means rely on request limit only. Nonzero caps messages/day/visitor. Useful against chatty scripts. Use when a buggy cron is the threat model more than request rate. |
| `visitor-email-limit-burst` | `16` | Burst for email-sending path. Irrelevant if SMTP unset. Prevents mail floods when email is on. Set only after SMTP works; otherwise you will debug the wrong layer. |
| `visitor-email-limit-replenish` | `1h` | Replenish for email limiter. Pair with burst. Slow replenish is what stops a looped alert from mailing you into oblivion. Leave at 1h until SMTP is actually enabled and you have a measured abuse case. |
| `visitor-prefix-bits-ipv4` | `32` | Visitor aggregation prefix for IPv4 (`/32` = per IP). Lower aggregates more (NAT-friendly, less precise). Wrong value under proxy makes everyone one visitor. With HAProxy and behind-proxy true, /32 per real client is usually right. |
| `visitor-prefix-bits-ipv6` | `64` | Same for IPv6. `/64` is a common guest aggregation. Tighten only if you know your v6 layout. If you see unfair shared limits, your proxy may be collapsing v6 to one address — fix that first. |
| `visitor-subscriber-rate-limiting` | `false` | Extra UnifiedPush-oriented subscriber limiting. Off unless you need it. Enabling can surprise UP clients. I leave it false until a specific UP abuse case shows up. |
| `stripe-secret-key` / `webhook-key` | `<secret>` | Billing — do not use for a private lab. Leaving unset is correct. If set, protect webhooks. Homelab ntfy is not a billing product; keep these unset forever here. |
| `billing-contact` | unset | Only with Stripe. Leave unset. No Stripe means no contact field; ignore in private deployments. Seeing this set is a smell that billing yaml leaked into the lab server. |
| `enable-metrics` | unset | Prometheus metrics toggle. If on, protect `/metrics` via proxy ACLs. Do not expose publicly. If you scrape, bind metrics privately and ACL the path like any admin endpoint. |
| `metrics-listen-http` | unset | Separate metrics listen; also implies metrics on. Bind loopback or firewall. Prefer a dedicated loopback metrics port over exposing it on the main listener. Unset means metrics stay off unless `enable-metrics` forces another path. |
| `profile-listen-http` | unset | Go pprof endpoints — private only while debugging, then off. Leaving on is an info leak and CPU burn risk. Never leave pprof enabled between debug sessions on an edge box. Force-recreate after clearing it so the listen socket actually dies. |
| `log-level` | `info` | `trace`/`debug`/`info`/`warn`/`error`. Debug is for incidents; leave info daily. Trace is extremely noisy. Bump to debug only while reproducing; revert before the disk fills with noise. |
| `log-level-overrides` | unset | Temporary per-subsystem overrides. Great for one bug, bad if forgotten. Clear after use. Write down why an override exists or you will never dare remove it. |
| `log-format` | `text` | Or `json` for log shippers. Pick one and stick to it in scrapers. Changing breaks naive parsers. JSON is nicer for Loki; text is nicer for `nerdctl logs` eyeballing. |
| `log-file` | unset | Leave unset so logs go to container runtime/journal. File logging inside the container needs rotation mounts. Prefer runtime logs on compose hosts. If you must log to a file, mount a host path and rotate it outside the container. |

edit ignored `config/server.yml`, then `./scripts/up.sh` (force-recreate for web push / container-level changes).
