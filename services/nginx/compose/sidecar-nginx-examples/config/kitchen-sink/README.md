# kitchen sink

one conf that stacks the common bits: basic auth, security headers, gzip, rate limit, proxy cache, websocket upgrade headers.

tls is left out on purpose - terminate on the edge, or use `config/tls` when you really want certs on this container.

## setup

1. `./scripts/htpasswd.sh`
2. in `compose.yml`, uncomment:

```yaml
- ./secrets/htpasswd:/etc/nginx/htpasswd:ro
- nginx-cache:/var/cache/nginx
```

and:

```yaml
volumes:
  nginx-cache:
```

3. in `.env`:

```sh
NGINX_CONF=./config/kitchen-sink/nginx.conf
```

4. `./scripts/up.sh`

## when to use

mostly as a reference. real deploys usually pick 2-3 of these, not all of them. caching + auth especially needs care (see `config/cache/README.md`).


&nbsp;

**466f724a616e6574**
