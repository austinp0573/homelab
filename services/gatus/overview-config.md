# gatus config

compose `.env` + yaml under `config/`. Gatus loads every `*.yaml`/`*.yml` in `GATUS_CONFIG_PATH`. maps deep-merge, `endpoints` append, scalars must not duplicate across files.

## compose `.env`

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `gatus` | Docker Compose project prefix for containers, networks, and volumes. changing it mid-life orphans the old named resources unless you migrate carefully. keep stable so scripts and muscle memory (`docker compose -p gatus`) stay aligned. Renaming mid-flight orphans volumes unless you migrate them on purpose. |
| `CONTAINER_NAME` | `gatus` | fixed container name for logs, HAProxy backends, and smoke scripts. colliding names with another stack on the same host fails `up` immediately. don’t rename casually — proxy configs hardcode this often. Proxy backends and smoke scripts often hardcode this string. |
| `RESTART_POLICY` | `unless-stopped` | restarts after reboot/crash unless you explicitly stopped it. monitoring that doesn’t come back after a host reboot is worse than a flaky check. `always` is overkill; `no` is how you forget it died overnight. Use an explicit stop for maintenance; otherwise expect it back after reboot. |
| `GATUS_IMAGE` | `ghcr.io/twin/gatus:v5.35.0` | pinned image; uncomment/override in `.env` when bumping. floating tags pull surprise breaking YAML schema changes. smoke after upgrades — storage and alerting keys move between majors. Read release notes on major bumps; storage and alert keys do move. |
| `HOST_BIND` | `127.0.0.1` | publish only on loopback for same-host HAProxy/Tinyauth. `0.0.0.0` exposes the UI (and basic auth) to the LAN — only if intentional. wrong bind is a common “works locally, open to the world” footgun. Loopback plus an edge proxy is the usual safe exposure model. |
| `HOST_PORT` | `8080` | host port mapped to container `8080`. conflict with another service on 8080 is an instant compose failure — pick another and update proxy backends. Prometheus scrape examples often assume this port via `host.docker.internal`. Change the left-side publish and update every caller in the same commit. |
| `DATA_DIR` | `./data` | host path for sqlite bind → `/data` in container. Wipe this and you lose history/status charts, not just cache. Back it up with the rest of the monitoring stack if history matters for postmortems. Wipe equals data loss unless you have a restore you have actually rehearsed; a fresh empty dir also resets uptime-since narratives people treat as gospel. |
| `GATUS_AUTH_USER` | `admin` | username written into `10-security.yaml` by `hash-password.sh`. keep in sync with yaml `security.basic.username` or login fails with no obvious mismatch hint. if you move to Tinyauth-only, this becomes dead config — remove basic auth then. Ignore this until the template actually wires it through. |
| `GATUS_CONFIG_PATH` | `/config` | in-container config dir; compose-hardcoded mount of `./config`. putting yaml elsewhere without updating the mount leaves Gatus on empty/default behavior. don’t bind-mount a single file if you rely on multi-file merge. Edit the compose/config that owns it — .env alone will not move hardcoded values. |

## secrets

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `secrets/password.txt` | `<secret>` | plaintext password for `hash-password.sh` only — not mounted into the container. leaving it around is fine if perms are tight; committing it is not. delete or rotate after hashing if you don’t want plaintext lingering next to the stack. Keep the real value out of git and shell history. |
| `security.basic.password-bcrypt-base64` | bcrypt+b64 of `change-me-now` in sample | **regenerate** with `./scripts/hash-password.sh` before exposing. the sample hash is public knowledge in the repo — shipping it is equivalent to no auth. Gatus wants bcrypt then base64; pasting raw bcrypt without the encode step fails auth mysteriously. Keep the real value out of git and shell history. |

## `00-storage.yaml`

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `storage.type` | `sqlite` | persistent results in a single file; memory mode loses history on restart. fine for homelab scale; don’t point this at a network FS if you can avoid sqlite locking pain. changing type mid-flight doesn’t migrate old data. Operational detail matters here — verify against the running compose when unsure. |
| `storage.path` | `/data/gatus.db` | sqlite file under the mounted `DATA_DIR`. if the path isn’t writable (perms), Gatus starts but storage errors spam logs and history vanishes. keep path under `/data` so host backups catch it. Operational detail matters here — verify against the running compose when unsure. |
| `storage.maximum-number-of-results` | `200` | caps stored results per endpoint; higher = bigger DB and heavier UI. too low and you can’t see overnight flapping patterns. tune after you’ve lived with default growth a week. Operational detail matters here — verify against the running compose when unsure. |
| `storage.maximum-number-of-events` | `100` | caps event history per endpoint separately from results. events are the “went down / recovered” timeline — truncate too hard and postmortems lose context. raise if you alert-flap often and need the trail. Operational detail matters here — verify against the running compose when unsure. |

## `10-security.yaml`

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `security.basic.username` | `admin` | should match `GATUS_AUTH_USER` used by the hash script workflow. mismatch means you hash for one user and log in as another. if Tinyauth gates this later, drop Gatus basic auth entirely to avoid double prompts. Operational detail matters here — verify against the running compose when unsure. |
| `security.basic.password-bcrypt-base64` | *(see secrets)* | bcrypt hash, then base64 — Gatus-specific encoding, not a paste of htpasswd. Higher bcrypt cost slows every page load and health UI refresh; don’t crank cost for fun on a Pi. Regenerate whenever you rotate `password.txt`. Keep the real value out of git and shell history — the sample hash in-repo is public, so shipping it is equivalent to leaving basic auth off. |

if Tinyauth gates this later, drop Gatus basic auth (see tinyauth notes).

## `20-alerting.yaml` (copy from `.example`)

not loaded until copied to `20-alerting.yaml` (gitignored — can hold a token).

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `alerting.ntfy.url` | `https://ntfy.example.com` | ntfy base URL Gatus POSTs to; must be reachable from the Gatus container network. Wrong scheme/host fails silently into checks-red-phone-quiet. Use your real ntfy service URL, not the example. Prefer the name clients actually type — `localhost` from Gatus is Gatus itself, and a LAN IP the container can’t route is the same as a dead alerter. |
| `alerting.ntfy.topic` | `gatus` | topic name for alerts; subscribers must match exactly including case. shared topics with other tools mix noise — prefer a dedicated monitoring topic. ACL/token on the server must allow publish to this topic. Operational detail matters here — verify against the running compose when unsure. |
| `alerting.ntfy.token` | `""` / `<secret>` | bearer token when the topic is restricted; empty only for open topics (lab only). leaked token = spam your phone or steal your alert channel. keep this file gitignored — that’s why the example must be copied. Keep the real value out of git and shell history. |
| `alerting.ntfy.priority` | `3` | ntfy priority for alert pushes; higher wakes devices more aggressively. too high and overnight flap becomes sleep deprivation; too low and you miss real outages. pick once and keep consistent across endpoints. Tune from measured behavior, not the first number that felt safe. |
| `default-alert.failure-threshold` | `3` | consecutive failures before alert fires — primary flap damper. interval × threshold ≈ how long you’re blind before notify. lower for critical edge, higher for flaky home WAN checks. Tune from measured behavior, not the first number that felt safe. |
| `default-alert.success-threshold` | `2` | consecutive successes before resolve; prevents green/red spam on blips. pair with failure-threshold so you don’t resolve every other scrape. endpoints inherit this unless overridden. Tune from measured behavior, not the first number that felt safe. |
| `default-alert.send-on-resolved` | `true` | sends a recovery notification when the check clears. turn off if you only care about “down” and hate resolve noise. leave on when on-call needs confirmation that it’s back. Operational detail matters here — verify against the running compose when unsure. |

endpoints still need `alerts: [{ type: ntfy }]` even with `default-alert`.

## endpoints (e.g. `endpoints/edge.yaml`)

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `endpoints[].name` | *(id)* | unique check id in UI and alerts; duplicates confuse merge/append behavior. use stable names — renaming loses mental continuity with history. keep short and DNS-ish (`edge-haproxy`, `openbao-health`). Use the name clients actually type, not a container-local address. |
| `endpoints[].group` | e.g. `edge` | UI grouping only; doesn’t affect routing. consistent groups make dashboards skim-able when you have dozens of checks. typo a group name and you get a new empty bucket forever. Use the name clients actually type, not a container-local address. |
| `endpoints[].url` | *(https…)* | target URL; replace placeholders with real hosts before trusting green. from inside the container, `localhost` is Gatus itself — use LAN/tailnet/host.docker.internal as appropriate. HTTPS checks need the name the cert actually serves. Hitting the IP with an HTTPS URL that expects a hostname fails TLS verify even when the service is fine — prefer the public/tailnet name you actually trust. |
| `endpoints[].interval` | `1m` | scrape cadence per endpoint; aggressive intervals amplify load and alert noise. global storage caps still apply — faster scrapes fill history windows quicker. align with how fast you actually need to know. Use the name clients actually type, not a container-local address. |
| `endpoints[].conditions` | status / latency / cert age | assert status codes, latency budgets, cert expiry, etc. — see the yaml file for exact expressions. OpenBao health must be **200** here; sealed/unhealthy responses are not “up.” wrong condition is how you greenwash a broken service. Latency-only checks without a status assert will stay green through 5xx if the body arrives fast enough — pair status + budget unless you mean otherwise. |
| `endpoints[].alerts[].type` | `ntfy` | required for alerting to fire even when `default-alert` exists — easy to forget. type must match a configured alerter (`ntfy`). missing this means perfect checks and zero pages. Use the name clients actually type, not a container-local address. |
| `endpoints[].alerts[].description` | *(text)* | human hint in the alert body; put the service name and what to check first. empty descriptions make phone buzzes useless at 3am. keep one-liners, not essays. Use the name clients actually type, not a container-local address. |
