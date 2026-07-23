# basic auth

nginx prompts for a password, then proxies to the upstream. useful when you want a quick gate on something that has no auth of its own.

for anything that already sits behind tinyauth / the edge gate, skip this - double login is annoying.

## setup

1. `./scripts/htpasswd.sh` (writes `secrets/htpasswd`)
2. in `compose.yml`, uncomment the htpasswd volume under `nginx:`

```yaml
- ./secrets/htpasswd:/etc/nginx/htpasswd:ro
```

3. in `.env`:

```sh
NGINX_CONF=./config/basic-auth/nginx.conf
```

4. `./scripts/up.sh`

smoke should get 401 without credentials, 200 with `-u user:pass`.

## alter compose

only the htpasswd mount is required on top of the default stack. change `proxy_pass` if the app is not `placeholder`.


&nbsp;

**466f724a616e6574**
