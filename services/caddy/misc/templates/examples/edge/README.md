# edge reverse proxy

caddy as the front door. publishes 80/443, terminates tls, routes by hostname.

copy this dir (or start from `../template/` and steal the Caddyfile). scripts are the same as the template - copy `scripts/` from there if you want `up.sh` / `down.sh` / `smoke.sh`.

## notes

- stock alpine, HTTP-01. dns pointing at this host required for real certs.
- backends are placeholders. `host.docker.internal` reaches the host; use container names if everything shares a compose network.
- unknown hosts hit `abort` so you do not accidentally serve the wrong thing.

see also: `../multi-host/`, `../http-01/`, `../security-headers/`.


&nbsp;

**466f724a616e6574**
