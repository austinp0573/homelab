# gatus

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### gatus

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~20-40 MB | image ~25 MB + small sqlite | periodic checks only |
| expected | 1-5% | ~50-100 MB (tens of endpoints) | sqlite grows with history retention | check probes + alert posts (ntfy) |
| high | 0.1-0.5 core | ~150-300 MB with huge histories / many endpoints | uncapped history can bloat disk | fast intervals across many endpoints |

deploy path on host: `/opt/gatus/`

uptime / status page. config is YAML on disk, history in sqlite. alerts go to ntfy (placeholder until you point it at a real server).

I expect to run this on the edge VPS so checks see the public HTTPS names even when the house is dark. the notes stay host-agnostic; same files work on any box that can reach the URLs.

## deploy

1. copy this directory to the host as `/opt/gatus/`
2. `cp .env.example .env` and edit
3. `cp secrets/password.txt.example secrets/password.txt` and put a long random password in it
4. `./scripts/hash-password.sh` (writes bcrypt into `config/10-security.yaml`)
5. `cp config/20-alerting.yaml.example config/20-alerting.yaml`, then set the ntfy url / topic / token
6. edit `config/endpoints/edge.yaml` - real hostnames
7. `mkdir -p data`
8. `./scripts/up.sh`
9. `./scripts/smoke.sh`

UI default: `http://127.0.0.1:8080` (bound to localhost). put haproxy in front for `https://status.example.com` - snippet in `haproxy/backend.example.cfg`.

login is HTTP basic auth (Gatus `security.basic`). username defaults to `admin`.

## layout

```text
/opt/gatus/
  .env
  compose.yml
  config/
    00-storage.yaml
    10-security.yaml
    20-alerting.yaml.example
    20-alerting.yaml      # ignored; may contain the ntfy token
    endpoints/
      edge.yaml
  data/                 # sqlite lives here (bind mount)
  secrets/password.txt  # only used by hash-password.sh
```

`GATUS_CONFIG_PATH` points at the `config/` directory. Gatus merges every `*.yaml` under it. maps deep-merge; `endpoints` lists append. see `config-explanations.md`.

`20-alerting.yaml.example` is not loaded. copy it to `20-alerting.yaml` before starting Gatus.

## ops

```sh
./scripts/up.sh
nerdctl compose logs -f
./scripts/smoke.sh
./scripts/down.sh
```

config reload: gatus watches the config dir. after edits, check logs. bad yaml keeps the old config until fixed (unless you restart into a broken file - then it will not start).

Compose checks `/health` every 30 seconds. `./scripts/smoke.sh` also checks the login behavior from the host.

## what this owns vs healthchecks

gatus: HTTPS / TCP / "is the service answering".

job heartbeats (restic, borgmatic cron): keep healthchecks-style pings. different problem.

## security note

public + HTTPS + a strong unique password is acceptable for a private status page. still treat the URL as sensitive (it maps your infra). do not reuse the password. rotate by editing `secrets/password.txt` and re-running `hash-password.sh`.

when ready for password+TOTP in front of the UI, see `services/tinyauth/` and `services/tinyauth/notes/gatus.md` (drop this basic auth after the gate works).


&nbsp;

**466f724a616e6574**
