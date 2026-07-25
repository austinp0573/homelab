# nocodb

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### nocodb

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 2-5% | ~150-250 MB | image ~500 MB; sqlite under ./data | idle |
| expected | 10-30% | ~250-500 MB | sqlite / uploads grow with bases | UI + API for a few users |
| high | 1-2 cores | ~1 GB+ | large bases / attachments | CSV import, many concurrent editors |

This compose uses sqlite in ./data (no separate postgres service).

deploy path on host: `/opt/nocodb/`

self-hosted airtable-ish UI. sqlite lives under `./data` (mounted at `/usr/app/data` in the container). first signup becomes the admin.

uses nocodb's own login. no tinyauth / basic-auth sidecar here.

## deploy

1. copy this directory to `/opt/nocodb/`
2. `cp .env.example .env`
3. set `NC_AUTH_JWT_SECRET` (`openssl rand -base64 32`)
4. set `NC_SITE_URL` to the public https name (e.g. `https://nocodb.private.example.com`)
5. `./scripts/up.sh`
6. `./scripts/smoke.sh`

local default: `http://127.0.0.1:8789`

put a reverse proxy in front for https. scrap in `haproxy/backend.example.cfg`.

## jwt secret

`NC_AUTH_JWT_SECRET` signs auth tokens. if it is empty, nocodb invents one at start - and invents another on the next restart, which logs everyone out. keep a stable value in `.env`.

`./scripts/up.sh` warns if the secret is missing or still `change-me`, but it will still start.

## signup lock

open signup is fine for first boot. after you have an admin account, lock it in the UI (super admin settings -> disable public signup / invite-only). do that before you put it on a public hostname.

## site url

`NC_SITE_URL` is what nocodb uses for share links, invites, and swagger when it sits behind a proxy. match whatever hostname haproxy serves.

## public shares

share a view/base from the UI when you want something public (optional password). keep `NC_SITE_URL` correct or those links will point at the wrong host.

## lan dbs / webhooks

left off on purpose:

- `NC_ALLOW_LOCAL_EXTERNAL_DBS` - connect nocodb to postgres/mysql on the lan
- `NC_WEBHOOK_ALLOW_PRIVATE_NETWORK` - webhooks to private rfc1918 / localhost

flip those in compose/`.env` only if you need them. both widen the attack surface.

## backup

sqlite + uploads live under `./data`. back that directory up. for a consistent sqlite copy, `scripts/backup/sqlite-backup.sh` in this repo can snapshot the db file; still include the rest of `data/` for attachments.

## images

default is `nocodb/nocodb:latest`. pin a tag or digest in `.env` (`NOCODB_IMAGE`) when you want a frozen deploy.

## layout

```text
/opt/nocodb/
  .env
  compose.yml
  data/
  haproxy/backend.example.cfg
```

## ops

```sh
./scripts/up.sh
nerdctl compose logs -f
./scripts/smoke.sh
./scripts/down.sh
```

scripts use `nerdctl compose` if present, otherwise `docker compose`.


&nbsp;

**466f724a616e6574**
