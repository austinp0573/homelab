# ntfy (homelab-edge)

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### ntfy

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~15-40 MB | image small; cache/auth sqlite usually MB | idle websocket subscribers |
| expected | 1-5% | ~40-100 MB | cache + attachments per config limits | push fanout to phones / browsers |
| high | 0.2-0.5 core | ~150-300 MB | attachment cache can be GBs if you allow it | burst alert storms / many subscribers |

deploy path on host: `/opt/ntfy/`

one compose stack. run it at home or on the edge VPS. public URL is always behind edge haproxy (`https://ntfy.example.com`).

this is the only supported ntfy setup in this repository.

## which host

| host | when |
|------|------|
| edge VPS | want alerts when the house is dark (gatus on edge can still publish). RAM budget is tight - see `notes/deploy-edge-vps.md` |
| home | more RAM/disk, fine for day-to-day. total home outage may also take ntfy down - see `notes/deploy-home.md` |

same files either way.

## deploy (either host)

1. copy this directory to `/opt/ntfy/`
2. `cp .env.example .env` and edit (`BASE_URL`, bind/port)
3. `cp config/server.yml.example config/server.yml` and edit
4. `mkdir -p data cache`
5. `./scripts/up.sh`
6. `./scripts/bootstrap-admin.sh` - creates admin user (web UI / phone app)
7. optional: `./scripts/webpush-keys.sh` then paste keys into `config/server.yml` and recreate
8. `./scripts/create-publisher.sh gatus` (and restic, borg, ...)
9. `./scripts/smoke.sh`
10. wire haproxy - `haproxy/backend.example.cfg`
11. point publishers at the public URL - `notes/integrations.md`

## auth model

- `auth-default-access: deny-all`
- one **admin** user for browser / phone (login)
- **publisher** users + access tokens for machines (gatus, restic, ...)
- each publisher gets write on its topic only

publisher topics use lowercase letters, numbers, hyphens, and underscores.

no anonymous publish. replace a publisher to revoke its old tokens:

```sh
./scripts/replace-publisher.sh gatus
```

reset the admin password:

```sh
./scripts/reset-admin-password.sh
```

attachments are enabled with a 10 MiB file limit, a 100 MiB total cache limit, and 24-hour expiry. message history is kept for seven days.

## layout

```text
/opt/ntfy/
  .env
  compose.yml
  config/server.yml
  data/           # auth.db, webpush.db
  cache/          # message cache, attachments
  secrets/        # optional local notes for tokens (gitignored)
  overview-env.md # settings reference
```

## ops

```sh
./scripts/up.sh
nerdctl compose logs -f
./scripts/smoke.sh
./scripts/down.sh
```

## related

- gatus ntfy stub: `services/gatus/config/20-alerting.yaml`
- restic/borg already have `NTFY_*` placeholders in places
- edge haproxy pattern: `services/edge/`
- settings reference: `overview-env.md`


&nbsp;

**466f724a616e6574**
