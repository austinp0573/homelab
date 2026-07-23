# deploy-home

run the same `/opt/ntfy/` compose on a home host. edge VPS only terminates TLS and proxies over headscale.

## why home

- more RAM/disk than a 1-2GB cloud box
- keeps the edge VPS thinner (haproxy + headscale + gatus already)

tradeoff: if the whole site/network is down, publishers at home and ntfy itself are often down together. edge gatus may detect public failures but fail to push if the proxy path to home ntfy is dead.

## steps

1. join the home host to headscale (host client, not only a sidecar, is simpler for haproxy backends).
2. copy `services/ntfy/homelab-edge/` to `/opt/ntfy/` on that host.
3. `.env`:
   - `HOST_BIND=0.0.0.0` (accept from tailnet)
   - `HOST_PORT=2586`
   - `BASE_URL=https://ntfy.example.com`
4. `config/server.yml` - same `base-url`, `behind-proxy: true`
5. `./scripts/up.sh` then bootstrap admin + publishers
6. from the edge VPS: `curl -sS http://<home-tailnet-ip>:2586/v1/health`
7. edge haproxy: use the "home" backend in `haproxy/backend.example.cfg` with that IP
8. DNS A/AAAA for `ntfy.example.com` -> edge VPS (not the home IP)
9. add name to certs / `HAPROXY_DOMAINS`, reload haproxy

## firewall

only the edge (and maybe LAN) should hit `:2586`. do not publish 2586 on the router WAN. headscale path is enough for the VPS.

## phone / web

apps use `https://ntfy.example.com` + admin login. they never need the home LAN IP.
