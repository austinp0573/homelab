# combining patterns

the drop-in confs are mutually exclusive (`NGINX_CONF` points at one file). to combine, either start from kitchen-sink and delete what you do not want, or copy blocks between confs.

## common ones

### proxy + basic auth

use `config/basic-auth` as-is. that is already proxy + auth.

### proxy + headers + gzip

copy the `gzip` block from `config/gzip` and the `add_header` lines from `config/headers` into `config/proxy/nginx.conf` (or keep a private conf under `config/local/` - gitignore if it has hostnames).

### proxy + websockets

use `config/websockets`. add auth only on non-ws locations if the browser client cannot do basic auth on the upgrade.

### static + basic auth

take `config/static`, add the `auth_basic` lines and the htpasswd volume from basic-auth.

### anything + cache

steal `proxy_cache_path` + the `proxy_cache` lines from `config/cache`, and add the `nginx-cache` volume. do not cache authed personalized responses blindly.

## kitchen sink

`config/kitchen-sink` is auth + headers + gzip + rate limit + cache + ws headers. good reference, heavy for most apps. tls stays separate (`config/tls` or the edge proxy).
