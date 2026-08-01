# chartdb

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### chartdb

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~10-30 MB | image ~50-100 MB (nginx + static SPA) | idle page loads |
| expected | 1-5% | ~20-50 MB | no server-side diagram storage | serving the SPA; work is in-browser |
| high | 0.1-0.3 core | ~64-128 MB | still small | many concurrent page loads |

### auth

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~5-15 MB | tiny | idle |
| expected | 1-3% | ~10-30 MB | htpasswd only | basic-auth checks on page load |
| high | 0.1-0.3 core | ~64 MB | logs if left unbounded | auth scrape / many hits |

deploy path on host: `/opt/chartdb/`

open-source database diagram editor ([ChartDB](https://github.com/chartdb/chartdb)). paste schema JSON from a single "smart query" — no database password is sent to this service. diagrams live in the browser. no in-app accounts; auth is the nginx basic-auth sidecar.

optional AI DDL export via OpenAI or an OpenAI-compatible endpoint (left blank by default). analytics disabled.

## deploy

1. copy this directory to `/opt/chartdb/`
2. `cp .env.example .env` and edit ports / optional AI if you want them
3. `./scripts/htpasswd.sh` (creates `secrets/htpasswd` — required)
4. `./scripts/up.sh`
5. `./scripts/smoke.sh`

local defaults (localhost):

- ui (no auth): `http://127.0.0.1:8792`
- auth sidecar: `http://127.0.0.1:8793`

put a reverse proxy in front for https. example acl/backend scraps in `proxy/backends.example.cfg`. point the public hostname at `AUTH_HOST_PORT`.

## .env bits that matter

`DISABLE_ANALYTICS` — defaults to `true`. ChartDB ships Fathom otherwise.

`OPENAI_API_KEY` **or** (`OPENAI_API_ENDPOINT` + `LLM_MODEL_NAME`) — optional AI export. leave blank for diagram-only. do not mix the two options.

## auth

basic auth is part of this stack. create `secrets/htpasswd` with `./scripts/htpasswd.sh` before `up`. point your reverse proxy at `AUTH_HOST_PORT`, not `HOST_PORT` (`HOST_PORT` stays bound for local debugging without the password prompt).

## images

default is floating `ghcr.io/chartdb/chartdb:latest`. override `CHARTDB_IMAGE` / `AUTH_IMAGE` in `.env` if you want a digest or tag pin.

## layout

```text
/opt/chartdb/
  .env
  compose.yml
  auth/nginx.conf
  secrets/htpasswd
  proxy/backends.example.cfg
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
