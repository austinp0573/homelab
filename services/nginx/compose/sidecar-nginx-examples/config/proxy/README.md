# reverse proxy (default)

this is the stock conf. compose already points `NGINX_CONF` here.

## what it does

listens on 80, proxies everything to `http://placeholder:80` on the compose network.

## swap in

```sh
# .env
NGINX_CONF=./config/proxy/nginx.conf
```

no extra volumes.

## point at a different app

edit `proxy_pass` in `nginx.conf`:

- same compose file: `http://myapp:8080;`
- app on the host: `http://host.docker.internal:8080;` and uncomment `extra_hosts` in compose.yml
- app in another stack: join that network, use the other service name

restart after edits: `./scripts/up.sh`


&nbsp;

**466f724a616e6574**
