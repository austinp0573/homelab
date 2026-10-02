# rate limit

simple per-IP request limit. 10 r/s with a short burst. tune `rate` / `burst` for the app.

## swap in

```sh
NGINX_CONF=./config/rate-limit/nginx.conf
```

no extra volumes.

## notes

behind haproxy, `$binary_remote_addr` is often the proxy unless you pass the real client and key off `$http_x_forwarded_for` (messy) or terminate limits on the edge instead. for a sidecar on localhost that only the local proxy hits, this mostly protects against a runaway client on the same host/tailnet path - still useful, just know what IP you are limiting.

login / token endpoints are the usual place to tighten this.


&nbsp;

**466f724a616e6574**
