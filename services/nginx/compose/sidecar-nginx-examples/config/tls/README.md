# tls

demo: self-signed certs on the sidecar. real life: usually terminate TLS on haproxy / the edge box instead, and keep this sidecar on plain HTTP localhost.

## self-signed demo

1. `./scripts/gen-self-signed.sh` (writes `secrets/certs/`)
2. in `compose.yml`:
   - uncomment the certs volume
   - publish 443 as well, e.g. add under `ports:`:

```yaml
- "${HOST_BIND:-127.0.0.1}:${TLS_HOST_PORT:-8443}:443"
```

3. in `.env`:

```sh
NGINX_CONF=./config/tls/nginx.conf
```

4. `./scripts/up.sh`

curl will complain about the cert - use `-k` for a quick check.

## real certs (certbot / let's encrypt)

homelab edge almost always wants certs on the public proxy, not inside every app sidecar. options that have worked here:

1. **prefer: terminate on haproxy / caddy / whatever faces the internet**
   - certbot (or acme) runs on that host
   - sidecar stays `listen 80` on 127.0.0.1
   - less moving parts per app

2. **certbot on the host, mount into nginx**
   - issue with webroot or dns challenge on the host
   - point `ssl_certificate` / `ssl_certificate_key` at the live files (often `/etc/letsencrypt/live/NAME/fullchain.pem` and `privkey.pem`)
   - mount that path read-only into the container instead of `secrets/certs`
   - reload nginx after renew (`nerdctl compose exec nginx nginx -s reload` from a deploy hook, or restart the container)

3. **certbot in a companion container**
   - works, but you then own renewal + shared volumes + who binds :80 for http-01
   - only worth it if this sidecar *is* the public edge

http-01 needs :80 reachable from the internet on the cert hostname. dns-01 is nicer on a tailnet-only box.

do not commit real private keys. `secrets/certs/` is gitignored.


&nbsp;

**466f724a616e6574**
