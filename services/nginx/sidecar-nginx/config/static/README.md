# static files

sidecar serves files itself - no upstream. good for a small status page, docs dump, or anything that is just html/css/js.

## setup

1. put files in `./static/` (create it). start with a copy of `placeholder/html/index.html` if you want something to hit.
2. in `compose.yml`, uncomment:

```yaml
- ./static:/usr/share/nginx/html:ro
```

you can leave the `placeholder` service running or remove it from compose for this pattern - it is unused here.

3. in `.env`:

```sh
NGINX_CONF=./config/static/nginx.conf
```

4. `./scripts/up.sh`

## alter compose

only the html volume. no proxy_pass, no htpasswd unless you combine with basic-auth (see root README).


&nbsp;

**466f724a616e6574**
