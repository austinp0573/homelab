# proxy cache

caches successful upstream responses on disk inside the container (or a named volume).

## setup

1. in `compose.yml`, uncomment the cache volume mount under `nginx:`:

```yaml
- nginx-cache:/var/cache/nginx
```

and at the bottom:

```yaml
volumes:
  nginx-cache:
```

2. in `.env`:

```sh
NGINX_CONF=./config/cache/nginx.conf
```

3. `./scripts/up.sh`

`X-Cache-Status` on the response shows MISS/HIT/BYPASS/etc.

## notes

fine for mostly-static or slow-changing GETs. do not cache authenticated or personalized responses without thinking - this conf caches all 200s under `/`. for real apps, narrow `location` or add `proxy_cache_bypass` on cookies/auth headers.


&nbsp;

**466f724a616e6574**
