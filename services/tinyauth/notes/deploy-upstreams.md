# deploying gated upstreams

HAProxy, Tailscale, Tinyauth, and the gate run on the edge VPS. Tailscale controls how traffic reaches HAProxy. It does not make host loopback ports reachable from the gate container.

Use one external Nerdctl network for the gate and every local app that it protects.

## shared network

Create it once on the edge VPS:

```sh
nerdctl network create edge-apps
```

The Tinyauth gate already joins `edge-apps`.

## gatus

Add the external network to the Gatus Compose file:

```yaml
services:
  gatus:
    networks:
      - edge-apps

networks:
  edge-apps:
    external: true
```

Keep Gatus's host port bound to `127.0.0.1` for local health checks. The gate reaches the container directly at `http://gatus:8080` over `edge-apps`.

Start Gatus before Tinyauth so nginx can resolve the `gatus` service name.

## HAProxy

HAProxy stays on the edge VPS and reaches:

```text
127.0.0.1:3000  tinyauth login
127.0.0.1:8088  tinyauth gate
```

Use the host ACLs and backends from `../haproxy/backends.example.cfg`.

## other local apps

For another app running in a separate Nerdctl Compose project:

1. attach its service to `edge-apps`
2. use its Compose service name and internal port in `gate/nginx.conf`
3. add the hostname ACL in HAProxy
4. restart the app and the gate

Do not use `host.docker.internal` for an app bound only to host loopback. The host gateway is not `127.0.0.1`.

## tailnet apps

If an app stays on a different tailnet host, point the gate at its tailnet IP or MagicDNS name instead. Use HTTPS upstream settings when that app serves TLS.

The OpenBao and TrueNAS blocks in `gate/nginx.conf` are templates. Do not add their HAProxy hostnames until their upstream address and TLS behavior are known.
