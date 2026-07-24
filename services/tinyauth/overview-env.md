# tinyauth env

login app + nginx gate on external `edge-apps` network. create the network before up. cookie parent = parent domain of `TINYAUTH_APPURL` — one trust boundary per parent.

## `.env` / compose

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `tinyauth` | Compose project for Tinyauth + the nginx gate. Stable name keeps the data dir association obvious when you have multiple edge apps. Renaming mid-life does not move `./data` but does confuse scripts. I keep this as the SSO project name on the edge host. |
| `RESTART_POLICY` | `unless-stopped` | Both login and gate should survive reboot — auth outages take down every gated app. Stopping Tinyauth while leaving gate up yields systemic 401/redirect loops. Do not use `no` unless you are debugging a broken cookie domain. When rotating users or TOTP, recreate deliberately rather than relying on a crashy restart loop. |
| `TINYAUTH_CONTAINER_NAME` | `tinyauth` | Login app container name. HAProxy `be_tinyauth` points at its published port, not necessarily this DNS name. Keep unique on the edge host. Logs for login failures live here, not in the gate. |
| `GATE_CONTAINER_NAME` | `tinyauth-gate` | Nginx forward-auth / subrequest gate container. Separate from Tinyauth so you can reload nginx configs without restarting the IdP-ish app. HAProxy backends for gated apps hit this, not Tinyauth directly. Misnaming breaks `up.sh` assumptions and mental models. |
| `TINYAUTH_IMAGE` | `ghcr.io/tinyauthapp/tinyauth:v5.0.7` | Pinned Tinyauth v5 image. Auth apps are not where you want floating `latest`. Upgrades can change cookie/session semantics — read release notes and expect a re-login. Match gate behavior to this major. |
| `GATE_IMAGE` | `nginx:1.27-alpine` | Pinned nginx for the gate. Boring on purpose. Config in `gate/nginx.conf` is the real logic; image bumps rarely fix app routing bugs. Keep alpine variant unless you need extra modules. |
| `TINYAUTH_APPURL` | `https://auth.private.example.com` | Public HTTPS URL of the login UI. Cookie parent domain is derived from this — `auth.private.example.com` ⇒ trust `.private.example.com`. Wrong APPURL breaks redirects and cookies across apps on sibling hosts. One parent domain per Tinyauth deployment; do not share across unrelated DNS trees. |
| `HOST_BIND` | `127.0.0.1` | Publish bind for both containers when HAProxy sits on the same host. Loopback stops LAN from bypassing HAProxy TLS/ACLs. If HAProxy is remote, you need a different reachability story — not a casual `0.0.0.0`. If you must bind wider, tighten nftables first and keep Tinyauth off untrusted broadcast domains. |
| `TINYAUTH_HOST_PORT` | `3000` | Host port → Tinyauth `:3000`. HAProxy `be_tinyauth` should match. Collision with Open WebUI or Grafana on 3000 is common on crowded hosts — move with intent. Only the login hostname should route here. |
| `GATE_HOST_PORT` | `8088` | Host port → gate nginx `:80`. HAProxy `be_tinyauth_gate` targets this for forward-auth checks. Health expectation is often `GET /auth-health` → **401** (unauthenticated = alive). Do not point browsers at the gate as a UI. |
| `DATA_DIR` | `./data` | Host directory for sqlite DB and session state. Lose this and every user re-auths; TOTP seeds may be gone depending on what you stored. Permissions matter — container user must write. Back up before upgrades. |
| `TINYAUTH_DATABASE_PATH` | `/data/tinyauth.db` | In-container sqlite path; effectively hardcoded relative to the data mount. Pointing env elsewhere without updating the volume mount leaves you on an empty DB. Do not put the DB on ephemeral writable layers. Treat path changes as a migration. |
| `TINYAUTH_AUTH_SECURECOOKIE` | `true` | Marks cookies Secure — requires HTTPS on `TINYAUTH_APPURL`. `false` only for broken local HTTP experiments. Mismatch with HTTP APPURL means cookies never stick. Leave true behind HAProxy TLS termination. |
| `TINYAUTH_AUTH_TRUSTEDPROXIES` | `127.0.0.1/32,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16` | CIDRs Tinyauth trusts for `X-Forwarded-*` (the gate/HAProxy path). Needed so redirects and client IP logic work behind proxies. Over-broad trust on an exposed Tinyauth bind lets clients spoof forwards — keep Tinyauth on loopback. Tighten if your proxy topology is simpler. |
| `TINYAUTH_AUTH_SESSIONEXPIRY` | `86400` | Session lifetime in seconds (1 day default). Shorter means more login prompts; longer means stolen cookie lasts longer. Not a substitute for TOTP on admin users. Changing it does not rewrite existing sessions magically — expect re-login. |
| `TINYAUTH_AUTH_USERS` | filled by `up.sh` | Injected at start from `config/users` bcrypt lines. **Do not** paste password hashes into `.env` or commit them. Empty in git is correct; runtime env in the container will hold hashes + optional TOTP seeds. Edit `config/users` and recreate to apply. |
| `TINYAUTH_ANALYTICS_ENABLED` | `false` | Disables whatever phoning-home/analytics the app supports. Keep false on a private auth box. Turning on adds outbound noise you do not need. Not related to your own access logs. |
| `TINYAUTH_LOG_LEVEL` | `info` | Log verbosity for Tinyauth. `debug` is useful for cookie/redirect fights, then turn it back down. Too noisy logs hide real auth failures. Gate nginx has its own access/error logs — check both. |
| `COMPOSE_CMD` | `nerdctl compose` | Optional override for scripts that shell out to compose. Use when the host's `docker compose` vs `nerdctl` differs. Wrong binary makes `up.sh` fail in confusing "command not found" ways. Keep consistent with the rest of the edge host. |
| network `edge-apps` | external | User-defined external network both containers join. Must exist before up — compose will not create `external: true` networks. Used so other edge apps can resolve/reach the gate if needed. Forgetting create is the first-boot failure mode. |

## `config/users`

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| line format | `user:bcrypt` or `user:bcrypt:totp_secret` | One user per line; use `create-user.sh` / `enable-totp.sh` rather than hand-rolling bcrypt. Restart/recreate after edits so `up.sh` re-injects `TINYAUTH_AUTH_USERS`. bcrypt hashes and TOTP seeds are `<secret>` — keep `config/users` out of git if it holds live secrets. Broken lines fail login for that user only, which is easy to misread as a cookie bug. |

## HAProxy (edge)

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `be_tinyauth` | `127.0.0.1:3000` | HAProxy backend for the login hostname → Tinyauth UI. Must match `HOST_BIND`/`TINYAUTH_HOST_PORT`. TLS and the public name live on HAProxy, not in Tinyauth. Wrong port shows 503 while gate checks might still pass oddly. |
| `be_tinyauth_gate` | `127.0.0.1:8088` | Forward-auth backend. Probe `GET /auth-health` expecting **401** when unauthenticated — 200 usually means you are checking the wrong thing or auth is wide open. Gated apps' HAProxy configs should auth against this, not against Tinyauth:3000. Upstream hostnames for Gatus/bao-ui/TrueNAS live in `gate/nginx.conf` — edit there for real targets. |

gate upstreams (Gatus / bao-ui / TrueNAS hostnames) live in `gate/nginx.conf` — edit for real targets. running container env holds hashes + TOTP seeds.
