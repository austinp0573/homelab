# caddy template

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### caddy

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~30-50 MB | image ~40-50 MB + cert storage | idle HTTPS |
| expected | 2-10% | ~50-150 MB | certs + small config; OCSP/cache modest | normal reverse-proxy traffic |
| high | 0.5-2 cores | ~200-500 MB+ | grows with certs / large file cache if used | many concurrent connections or big static transfers |

deploy path: `/opt/caddy/`

stock alpine image. one Caddyfile, HTTP-01 TLS by default. edit the file for hostnames and backends, then bring it up.

## deploy

1. copy this directory to `/opt/caddy/`
2. `cp .env.example .env` and edit
3. edit `Caddyfile`
4. `./scripts/up.sh`
5. `./scripts/smoke.sh`

data dir holds certs / acme state. keep it across recreates.

## defaults

- binds `80` and `443` on `HOST_BIND` (default `0.0.0.0`)
- admin API off
- logs to stdout (compose logs)
- placeholder site block in `Caddyfile` - replace before real use

for lab-only / behind another proxy, set `HOST_BIND=127.0.0.1`. HTTP-01 from the public internet needs 80 reachable on the real address.

## ops

```sh
./scripts/up.sh
nerdctl compose logs -f
./scripts/smoke.sh
./scripts/down.sh
```

## related

- more patterns: `../examples/`
- native alpine install notes: `../../` (parent of compose/)


&nbsp;

**466f724a616e6574**
