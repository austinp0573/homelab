# excalidraw

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### excalidraw

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~10-30 MB (static nginx) | image ~50-100 MB | idle page loads |
| expected | 1-5% | ~20-50 MB | no server-side drawing storage | serving the SPA |
| high | 0.1-0.3 core | ~64-128 MB | still small | many concurrent page loads |

### room

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~20-40 MB | negligible state | websocket idle |
| expected | 1-5% | ~40-80 MB | ephemeral relay only | collab traffic for a few rooms |
| high | 0.2-0.5 core | ~128-256 MB | still small | many busy collab rooms |

### auth

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~5-15 MB | tiny | idle |
| expected | 1-3% | ~10-30 MB | htpasswd only | basic-auth checks on page load |
| high | 0.1-0.3 core | ~64 MB | logs if left unbounded | auth scrape / many hits |

auth is the optional nginx basic-auth front.

deploy path on host: `/opt/excalidraw/`

self-hosted whiteboard. frontend + `excalidraw-room` for live collab. nothing is stored on the server - drawings live in the browser (and in the share-link key for collab). room only relays encrypted traffic.

this is intentionally separate from the edge tinyauth stack. if you want a password on the ui, use the optional nginx basic-auth sidecar here.

## deploy

1. copy this directory to `/opt/excalidraw/`
2. `cp .env.example .env` and edit the public hostnames
3. optional auth: `./scripts/htpasswd.sh`, then set `ENABLE_BASIC_AUTH=y` in `.env`
4. `./scripts/up.sh`
5. `./scripts/smoke.sh`

local defaults (localhost):

- ui: `http://127.0.0.1:5000`
- room: `http://127.0.0.1:5001`
- auth sidecar (if enabled): `http://127.0.0.1:5002`

put a reverse proxy in front for https. example acl/backend scraps in `proxy/backends.example.cfg`. collab needs websocket upgrades.

## .env bits that matter

`VITE_APP_WS_SERVER_URL` - public https url of the room (e.g. `https://collab.private.example.com`). the image bakes in `oss-collab.excalidraw.com`; compose rewrites that in the js assets on start.

`CORS_ORIGIN` - public https origin of the ui (e.g. `https://draw.private.example.com`). must match what the browser actually uses.

do not point basic auth at the room port. gate the ui only (auth sidecar or your own proxy). room stays open to whoever can reach it; keep it on localhost / tailnet and lock CORS.

## tailnet

fine to expose over the tailnet. keep `HOST_BIND=127.0.0.1` and terminate on a proxy that listens on the tailnet ip, or bind the published ports to the tailnet address. same files either way - just change bind/ports and the two public names in `.env`.

## auth

`ENABLE_BASIC_AUTH=y` starts an nginx sidecar that prompts for http basic auth, then proxies to the ui container. create `secrets/htpasswd` with `./scripts/htpasswd.sh`. when auth is on, point your reverse proxy at `AUTH_HOST_PORT`, not `UI_HOST_PORT` (ui port is still bound for local debugging).

leave edge tinyauth alone for this - that gate is for the more sensitive stuff.

## images

defaults are `:latest`. for a pinned deploy, set digests or tags in `.env` (`EXCALIDRAW_IMAGE`, `ROOM_IMAGE`).

## layout

```text
/opt/excalidraw/
  .env
  compose.yml
  auth/nginx.conf
  secrets/htpasswd   # only if using basic auth
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
