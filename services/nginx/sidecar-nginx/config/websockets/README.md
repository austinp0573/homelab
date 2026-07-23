# websockets

proxy with HTTP/1.1 upgrade headers and long timeouts. the placeholder here is plain HTTP, so this conf is mostly a copy-paste starting point for real ws apps (collab servers, terminals, etc).

## swap in

```sh
NGINX_CONF=./config/websockets/nginx.conf
```

no extra volumes. change `proxy_pass` to the ws-capable upstream.

## notes

if haproxy is in front, it also needs websocket/tunnel support (`timeout tunnel`, http upgrade). see `proxy/backends.example.cfg`.

basic auth on a ws endpoint is painful for browsers - gate the UI, leave the ws path alone when you can.


&nbsp;

**466f724a616e6574**
