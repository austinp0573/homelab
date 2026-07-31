# config explanations

Gatus loads every `*.yaml` / `*.yml` under `config/` (and subdirs) when `GATUS_CONFIG_PATH` is a directory.

- maps (storage, security, alerting, ...) are deep-merged
- lists like `endpoints` are appended across files
- a scalar key may only appear once (do not define `alerting.ntfy.topic` in two files)

file order in the name (`00-`, `10-`, ...) is for humans. merge is not "last wins" for conflicting scalars - avoid duplicates.

---

## `00-storage.yaml`

sqlite file at `/data/gatus.db` inside the container (host `./data`).

`maximum-number-of-results` / `maximum-number-of-events` cap history per endpoint so the db does not grow forever.

---

## `10-security.yaml`

HTTP basic auth for the dashboard and API.

`password-bcrypt-base64` is: bcrypt hash of the password, then base64-encoded. do not put the plaintext password in yaml.

generate with `./scripts/hash-password.sh` (reads `secrets/password.txt`).

cost ~10 is fine. higher cost slows every page load because basic auth verifies on each request.

---

## `20-alerting.yaml.example`

copy this file to `20-alerting.yaml` before starting Gatus. the copied file is ignored because it can contain the ntfy access token.

ntfy provider. set:

- `url` - your ntfy base URL (placeholder `https://ntfy.example.com`)
- `topic` - topic name
- `token` - access token if the topic is restricted; empty if open
- `default-alert` - failure/success thresholds applied when an endpoint only says `type: ntfy`

endpoint files still need an `alerts:` entry with `type: ntfy` to actually send.

until ntfy is real, bad url/token just means alerts fail in the logs; checks still run.

---

## `endpoints/edge.yaml`

starter HTTPS checks for the edge front door:

- headscale
- vault (vaultwarden)
- bao (openbao)

replace `example.com` names with yours. paths match what haproxy healthchecks already use in `services/edge/haproxy/backends.example.cfg`.

OpenBao `/v1/sys/health` must return `200`. A sealed node is not usable and should alert.

interval `1m` is enough for homelab. lower only if you like more noise.

---

## adding more endpoints

drop another file under `config/endpoints/`, e.g. `site1.yaml`. restart or wait for reload. keep one logical group per file if that helps you.

no MagicDNS required - use public hostnames or raw IPs in the URL.
