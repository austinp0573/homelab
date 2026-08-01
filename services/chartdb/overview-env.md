# chartdb env

static SPA (database diagram editor) + nginx basic-auth sidecar. no server-side diagram storage — browser only. ChartDB has no in-app accounts.

## .env / compose

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `chartdb` | Prefixes containers/networks for this stack. Changing mid-life orphans old resources unless you tear down first. Keep unique per host if you run multiple ChartDB copies. Scripts assume this name unless overridden. |
| `CHARTDB_CONTAINER_NAME` | `chartdb` | UI container name for logs/exec/proxy upstreams. Collision fails create on the engine. Renaming breaks `auth` upstream hostname only if you also change the compose service DNS — container_name ≠ service name. Leave stable once bookmarked. |
| `AUTH_CONTAINER_NAME` | `chartdb-auth` | Nginx basic-auth front container. This is what reverse proxies should hit (`AUTH_HOST_PORT`), not the raw UI. Stopping auth while leaving UI published exposes an unauthenticated SPA on `HOST_PORT`. Keep both up in normal use. |
| `RESTART_POLICY` | `unless-stopped` | Comes back after reboot unless you explicitly stopped it. Fine for a diagramming SPA. Switch to `always` only if a manual stop should not survive reboot. Restart loops usually mean missing `htpasswd` or bad nginx config. |
| `CHARTDB_IMAGE` | `ghcr.io/chartdb/chartdb:latest` | Floating latest; pin tag/digest once you care about UI stability. Image is static assets + entrypoint that writes `/config.js` from env. Recreate after AI/analytics env changes so config.js regenerates. GHCR pull needs network at up time. |
| `AUTH_IMAGE` | `nginx:1.27-alpine` | Thin basic-auth reverse proxy in front of ChartDB. Pin stays intentional — bump when you want nginx CVEs fixed. Relies on mounted `nginx.conf` + `htpasswd`. Wrong image without auth modules breaks the gate. |
| `HOST_BIND` | `127.0.0.1` | Keep loopback behind a reverse proxy / tailnet gateway. `0.0.0.0` exposes UI+auth ports on all interfaces — only do that with firewall intent. Tailnet access usually means proxy on this host, not wide bind. Changing bind does not change container-internal listen. |
| `HOST_PORT` | `8792` | Direct UI publish (no auth). For local debug only — production path is `AUTH_HOST_PORT`. Leaving this open on a shared host bypasses basic auth entirely. Point bookmarks at auth port once wired. |
| `AUTH_HOST_PORT` | `8793` | **Use this** behind your reverse proxy. Nginx challenges basic auth then proxies to `chartdb:80` on the compose net. HAProxy/Caddy backends should target `127.0.0.1:8793` (or bind IP). Do not also expose `HOST_PORT` publicly. |
| `DISABLE_ANALYTICS` | `true` | Turns off Fathom analytics in the UI via injected config. Set false only if you knowingly want outbound analytics. Injected at container start into `/config.js` — recreate to apply. Homelab default should stay true. |
| `HIDE_CHARTDB_CLOUD` | *(empty)* | Set `true` to hide ChartDB cloud upsell chrome. Empty leaves upstream default UI affordances. Cosmetic only — no auth impact. Recreate container after changing so `/config.js` refreshes. |
| `OPENAI_API_KEY` | *(empty)* | Optional AI assist for DDL/export. Leave blank, or use this **or** the custom endpoint pair — not both. Key is `<secret>` if set; lands in `/config.js` at start. Mixing with `OPENAI_API_ENDPOINT` yields confusing client errors. |
| `OPENAI_API_ENDPOINT` | *(empty)* | OpenAI-compatible base URL (e.g. `http://…/v1`) for local/gateway LLMs. Requires `LLM_MODEL_NAME`. Do not set alongside `OPENAI_API_KEY`. Wrong base path (`/v1` missing) fails all AI calls while the SPA still works. |
| `LLM_MODEL_NAME` | *(empty)* | Model id for the custom endpoint path. Ignored if you only set `OPENAI_API_KEY`. Must match what the endpoint actually serves. Recreate after changes; config is baked at start. |

## auth / proxy notes

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `secrets/htpasswd` | *(from htpasswd.sh)* | Nginx basic auth file; gitignored. Required before `./scripts/up.sh` or auth container fails. Generate via `./scripts/htpasswd.sh` — do not hand-edit unless you know the format. Treat contents as `<secret>`; losing it means regenerating users. |
| auth nginx upstream | `chartdb:80` | Auth container proxies to the UI service on the compose net by service DNS. Pointing at host port from inside creates hairpin pain. If UI service name changes, update `nginx.conf` too. Health of auth ≠ health of ChartDB if upstream is down. |

AI env vars are injected at container start into `/config.js` by ChartDB's entrypoint. diagrams and pasted schema JSON stay in the browser.
