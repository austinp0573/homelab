# deploy-edge-vps

run the same `/opt/ntfy/` compose on the cloud VPS next to haproxy/headscale/gatus.

## why edge

gatus on the VPS can still publish when home is unreachable. that is the main reason to put ntfy here.

## RAM

rough idle on a stripped Debian box:

| process | ballpark |
|---------|----------|
| OS | 100-200MB |
| haproxy | 20-50MB |
| headscale | 50-150MB |
| gatus | 40-80MB |
| ntfy | 30-80MB |

that set can fit under ~1GB RSS if you do **not** add a heavy auth stack (Authentik/Authelia+redis/etc). ntfy itself is small.

if the VPS is already swapping with haproxy+headscale+gatus, keep ntfy at home instead (`deploy-home.md`).

compose vs native package: use this compose. same files as home, one less snowflake. native deb is fine too but then you maintain two install paths.

## steps

1. copy `services/ntfy/homelab-edge/` to `/opt/ntfy/` on the VPS.
2. `.env`:
   - `HOST_BIND=127.0.0.1`
   - `HOST_PORT=2586`
   - `BASE_URL=https://ntfy.example.com`
3. `config/server.yml` - `behind-proxy: true`, matching base-url
4. `./scripts/up.sh` then bootstrap admin + publishers
5. local check: `curl -sS http://127.0.0.1:2586/v1/health`
6. haproxy: localhost backend from `haproxy/backend.example.cfg`
7. DNS + cert for `ntfy.example.com` on this VPS
8. reload haproxy

## port map on the VPS

keep ntfy off 8080. headscale often owns `127.0.0.1:8080`, gatus may use another localhost port. 2586 is the default in this stack.

## gatus on the same box

point gatus ntfy url at `https://ntfy.example.com` (public) or `http://127.0.0.1:2586` (local). public URL exercises TLS+haproxy; local URL still works if DNS is half-broken. token required either way.
