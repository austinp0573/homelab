# examples

scraps and mini stacks for common caddy setups.

full compose stacks (copy, edit, run):

- `edge/` - terminate 80/443, route several hostnames
- `sidecar/` - caddy in front of one app on a shared compose network

Caddyfile only (paste into the template or an edge stack):

- `http-01/` - public ACME over port 80 (stock image)
- `dns-01/` - DNS challenge (needs custom image with a dns plugin)
- `internal-tls/` - caddy internal CA, fine for lab / tailnet
- `multi-host/` - several host matchers under one wildcard
- `single-service/` - one host, one backend
- `websocket/` - reverse_proxy with upgrade headers left alone
- `basic-auth/` - basicauth in front of a backend
- `forward-auth-tinyauth/` - tinyauth via forward_auth
- `static-files/` - file_server
- `spa/` - spa fallback to index.html
- `redirect/` - canonical host / https redirect
- `security-headers/` - headers block I usually start with

backends in these files are placeholders. swap in real addresses (`host.docker.internal:PORT`, container name, lan ip, etc.).


&nbsp;

**466f724a616e6574**
