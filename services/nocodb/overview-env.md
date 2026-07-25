# nocodb env

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `nocodb` | compose project prefix for containers/volumes. keep stable so `DATA_DIR` association stays obvious. renaming mid-flight orphans named resources. Scripts and muscle memory that assume `nocodb` will quietly break if you rename without a plan. |
| `CONTAINER_NAME` | `nocodb` | fixed name for logs and proxy backends. NocoDB has its own auth — still keep bind loopback unless gated. collisions fail `up`. Proxy backends and smoke scripts often hardcode this string. |
| `RESTART_POLICY` | `unless-stopped` | comes back after reboot with the same sqlite/uploads. unexpected stop loses availability of bases/APIs. use explicit stop for upgrades. A forgotten stop leaves you wondering why the UI is gone after reboot. |
| `NOCODB_IMAGE` | `nocodb/nocodb:latest` | prefer pin; `latest` moves and can change auth/UI behavior. smoke login and one base after bumps. major jumps sometimes need migration patience. Pin once the stack is boring so overnight recreates do not surprise you. |
| `HOST_BIND` | `127.0.0.1` | loopback for same-host proxy. `0.0.0.0` exposes NocoDB’s own login to the LAN — sometimes OK, often wider than you meant. pair with `NC_SITE_URL` when fronted. Loopback plus an edge proxy is the usual safe exposure model. |
| `HOST_PORT` | `8789` | → `:8080` in the container. change on conflict and update edge backends + site URL if clients use host:port. health/smoke often assume 8789. Change the left-side publish and update every caller in the same commit. |
| `DATA_DIR` | `./data` | SQLite + uploads — **back this up**. deleting it destroys bases, attachments, and users. put it on reliable disk; sqlite on flaky network mounts hurts. Wipe equals data loss unless you have a restore you have actually rehearsed. |
| `NC_AUTH_JWT_SECRET` | `<secret>` | **required** for stable logins. empty = new secret each restart → everyone logged out every bounce. rotate deliberately (expect re-login) and never commit the real value. Keep the real value out of git and shell history. |
| `NC_SITE_URL` | `https://nocodb.private.example.com` | public HTTPS URL for shares/invites/links NocoDB generates. wrong URL produces broken share links and redirect weirdness behind a proxy. set to the name users actually type. Share and invite links break loudly when this disagrees with the reverse proxy name. |
| `NC_DISABLE_TELE` | `true` | compose-hardcoded telemetry off. leave it; you’re not missing features. don’t confuse with your own webhook/telemetry into ntfy. Edit the compose/config that owns it — .env alone will not move hardcoded values. |
| `NC_DISABLE_ERR_REPORTS` | `true` | hardcoded — no error report phone-home. keep off-network. local logs still exist via docker logs. Edit the compose/config that owns it — .env alone will not move hardcoded values. |
| `NC_DISABLE_SUPPORT_CHAT` | `true` | hardcoded — hides support chat widgets. cosmetic/privacy; leave true for a clean private UI. Edit the compose/config that owns it — .env alone will not move hardcoded values. Turning it false phones outbound and adds UI chrome you did not ask for on a loopback-gated instance. |

optional wideners (README, not in `.env.example`): `NC_ALLOW_LOCAL_EXTERNAL_DBS`, `NC_WEBHOOK_ALLOW_PRIVATE_NETWORK` — increase attack surface. lock public signup after first admin. own auth (no Tinyauth in front by default).
