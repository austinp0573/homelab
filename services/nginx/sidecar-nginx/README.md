# sidecar nginx

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### placeholder

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~5-15 MB | tiny | idle |
| expected | 1-3% | ~10-30 MB | tiny | whatever sample upstream responses you hit |
| high | 0.1-0.3 core | ~64 MB | tiny | load tests against the sample app |

### nginx

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~5-15 MB (alpine) | image ~20-40 MB | idle |
| expected | 1-5% | ~10-40 MB | logs grow if not rotated | proxied request volume |
| high | 0.5-2 cores | ~64-200 MB with big buffers / many workers | access logs under heavy traffic | large static/file proxy bursts |

deploy path: `/opt/sidecar-nginx/`

reusable nginx sidecar pattern. default stack is a tiny placeholder upstream plus nginx in front. swap `NGINX_CONF` to try different configs under `config/`.

this is the "drop nginx next to an app" toolkit - basic auth, static, headers, ws, gzip, rate limit, cache, tls notes. for SSO / shared login on the edge box, use tinyauth instead of stacking basic auth everywhere.

## deploy

1. copy to `/opt/sidecar-nginx/`
2. `cp .env.example .env`
3. `./scripts/up.sh`
4. `./scripts/smoke.sh`

default: `http://127.0.0.1:8080` -> nginx -> placeholder

## patterns

set in `.env`, then up again:

| NGINX_CONF | notes |
|---|---|
| `./config/proxy/nginx.conf` | default reverse proxy |
| `./config/basic-auth/nginx.conf` | needs htpasswd mount |
| `./config/static/nginx.conf` | needs `./static` mount |
| `./config/headers/nginx.conf` | security headers |
| `./config/websockets/nginx.conf` | upgrade + long timeouts |
| `./config/gzip/nginx.conf` | gzip |
| `./config/rate-limit/nginx.conf` | per-ip limit |
| `./config/cache/nginx.conf` | needs cache volume |
| `./config/tls/nginx.conf` | needs certs + :443 publish |
| `./config/kitchen-sink/nginx.conf` | most of the above at once |

each dir has a short README for compose edits.

common combines: `notes/combines.md`. edge / haproxy: `notes/edge.md` and `proxy/backends.example.cfg`.

## point at a real app

same compose network: change `proxy_pass` to `http://servicename:port`.

app already running elsewhere: join its network, or use `host.docker.internal` (uncomment `extra_hosts` in compose.yml).

you can delete the `placeholder` service once something real is upstream.

## ops

```sh
./scripts/up.sh
./scripts/smoke.sh
./scripts/down.sh
./scripts/htpasswd.sh
./scripts/gen-self-signed.sh
```

scripts use `nerdctl compose` if present, otherwise `docker compose`.

## layout

```text
/opt/sidecar-nginx/
  .env
  compose.yml
  placeholder/
  config/
  scripts/
  secrets/          # htpasswd, certs - gitignored
  proxy/backends.example.cfg
```


&nbsp;

**466f724a616e6574**
