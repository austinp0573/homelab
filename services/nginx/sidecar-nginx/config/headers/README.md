# security headers

same as the base proxy, plus a few response headers. CSP here is intentionally strict - expect to loosen it for real apps (inline scripts, CDNs, etc).

## swap in

```sh
NGINX_CONF=./config/headers/nginx.conf
```

no extra volumes.

## notes

if something sits behind haproxy/tinyauth already, headers can live on either layer. putting them on the sidecar is fine when the sidecar is the thing that talks HTTP to clients on the host/tailnet side.

`server_tokens off` is already in every conf here.


&nbsp;

**466f724a616e6574**
