# edge / haproxy

usual layout here:

```text
internet/tailnet -> haproxy (tls) -> 127.0.0.1:HOST_PORT (this sidecar) -> app
```

keep `HOST_BIND=127.0.0.1` so the sidecar is not on the LAN. example backend scrap: `proxy/backends.example.cfg`.

## when to use this sidecar vs tinyauth

- **sidecar basic auth**: one-off password on a single app, or something that never hits the shared edge gate
- **tinyauth / edge gate**: shared login across services on the VPS
- do not stack both on the same hostname unless you like typing passwords twice

see also tinyauth notes under `services/tinyauth/`.

## tls

prefer certs on haproxy (or whatever terminates public https). leave the sidecar on http localhost.

if this nginx *is* the public listener, see `config/tls/README.md` for self-signed demo and certbot notes.

## websockets

haproxy needs tunnel/upgrade support for ws backends. timeout tunnel long enough for the app. do not put basic auth on the ws port if the client cannot send credentials on the handshake.
