# tailscale compose config

This is a sidecar setup. The app shares the Tailscale container network namespace, so the app gets the Tailscale IP and its ports live on the Tailscale container.

`.env` controls Compose and containerboot. `scripts/up.sh` reads it, prefers `secrets/authkey.txt`, adds the local helper flags, and starts Compose.

## current shape

- Tailscale uses kernel networking with `/dev/net/tun` and `privileged: true`.
- State is kept in the named `ts-state` volume.
- The sample nginx app shares the Tailscale network namespace.
- Port 80 in that shared namespace is published as `HOST_PORT` for local testing.
- Headscale is optional. Leave `HEADSCALE_URL` empty for Tailscale SaaS.

## compose settings

`COMPOSE_PROJECT_NAME`

Compose project name. Default: `tailscale-sidecar`. Change it only when more than one copy runs on the host.

`TAILSCALE_IMAGE`

Tailscale container image. The Compose default is `tailscale/tailscale:latest`.

`latest` follows new Tailscale releases automatically. Set a version tag when a repeatable deployment matters.

`APP_IMAGE`

Placeholder application image. Default: `nginx:alpine`. Replace this with the service that needs tailnet access.

`TS_CONTAINER_NAME`

Container name for the Tailscale sidecar. Default: `tailscale`.

`APP_CONTAINER_NAME`

Container name for the app. Default: `tailscale-app`.

`RESTART_POLICY`

Container restart policy. Default: `unless-stopped`. Use `no` for temporary manual tests.

`HOST_PORT`

Host port published to port 80 in the shared network namespace. Default: `8080`.

Remove the `ports:` block from `compose.yml` when the app should be tailnet-only. The app does not need its own `ports:` block because it shares Tailscale's network namespace.

## identity and login

`HEADSCALE_URL`

Local helper setting, not a native Tailscale variable. `scripts/up.sh` converts it into `--login-server=<url>` in `TS_EXTRA_ARGS`.

Leave it empty for Tailscale SaaS. Set it to the public Headscale URL for Headscale.

`TS_AUTHKEY`

Auth key used to join the tailnet. `secrets/authkey.txt` wins over this value. Keep the key out of `.env` when possible.

For a reusable sidecar, use a reusable tagged preauth key. The node tags still need to be allowed by the tailnet ACL policy.

`TS_AUTH_ONCE`

Only runs login when the saved state is not already authenticated. Default here: `true`.

Keep this enabled with a persistent state volume. Set it to `false` only when each container start must authenticate again.

`TS_HOSTNAME`

Node name on the tailnet. Default here: `sample-app`.

Use a name that identifies the app, not the host. Changing it renames the tailnet node.

`TS_STATE_DIR`

Tailscaled state directory. Default: `/var/lib/tailscale`.

The named volume is mounted at `/var/lib/tailscale`. Do not change this variable unless the volume mount target changes too, or state will stop persisting.

`TS_USERSPACE`

Use userspace networking instead of kernel TUN networking. Default here: `false`.

Userspace networking avoids `/dev/net/tun` and privileged container access, but is slower and does not support `TS_DEST_IP`, `TS_TAILNET_TARGET_IP`, or `TS_TAILNET_TARGET_FQDN`.

## routes and tailscale up flags

`TS_ROUTES`

Comma-separated subnet routes to advertise. Example: `192.168.1.0/24`.

Advertised routes need approval in the Tailscale or Headscale control plane. The host and container also need working IP forwarding for subnet routing.

`TS_EXTRA_ARGS`

Extra `tailscale up` flags. Examples:

```sh
TS_EXTRA_ARGS=--accept-routes
TS_EXTRA_ARGS=--ssh
```

Use this for settings without a dedicated environment variable. Avoid duplicating flags added by `scripts/up.sh`.

`TS_ADVERTISE_TAGS`

Local helper setting. `scripts/up.sh` turns it into `--advertise-tags=...`.

Example: `tag:container`. The auth key and ACL policy must allow the tag.

`TS_ADVERTISE_EXIT_NODE`

Local helper setting. Set it to `true` to add `--advertise-exit-node`.

Exit-node use needs an appropriate ACL policy and host forwarding. Leave it `false` for an ordinary sidecar.

`TS_TAILSCALED_EXTRA_ARGS`

Extra `tailscaled` daemon flags. Leave empty unless troubleshooting or using a specific advanced daemon option.

## DNS, proxies, and sockets

`TS_ACCEPT_DNS`

Accept tailnet DNS configuration. The image default is not to accept it.

Set it to `true` to use MagicDNS and tailnet DNS resolvers inside the shared network namespace. This also affects the sidecar app's DNS lookups.

`TS_SOCKS5_SERVER`

Address for a SOCKS5 proxy served by tailscaled. Example: `:1055`.

Do not expose this port broadly unless clients are intended to use it.

`TS_OUTBOUND_HTTP_PROXY_LISTEN`

Address for Tailscale's outbound HTTP proxy. Example: `:8080`.

This is a proxy feature, not the app's HTTP listener. Do not use the same port as the app.

`TS_SOCKET`

Path to the tailscaled LocalAPI socket. Default: `/var/run/tailscale/tailscaled.sock`.

Leave it alone unless another local process needs a different socket path.

`TS_DEST_IP`

Proxies incoming Tailscale traffic to one destination IP. This is for a proxy container, not the ordinary sidecar pattern.

It cannot be used with `TS_USERSPACE=true` or `TS_SERVE_CONFIG`.

`TS_TAILNET_TARGET_IP`

Proxies incoming non-tailnet traffic to a target Tailscale IP. This is an egress proxy mode.

It cannot be used with `TS_USERSPACE=true` or `TS_TAILNET_TARGET_FQDN`.

`TS_TAILNET_TARGET_FQDN`

Like `TS_TAILNET_TARGET_IP`, but uses a full MagicDNS name for the target.

It cannot be used with `TS_USERSPACE=true` or `TS_TAILNET_TARGET_IP`.

## serve, health, and metrics

`TS_SERVE_CONFIG`

Path to a JSON file containing Tailscale Serve or Funnel configuration.

The file needs a directory bind mount. Mounting one file does not support config reloads. It cannot be used with `TS_DEST_IP`.

`TS_ENABLE_HEALTH_CHECK`

Enables an unauthenticated `/healthz` endpoint. It returns success after the node has a tailnet IP.

This only enables the endpoint. Add a Compose `healthcheck:` if the container runtime should act on it.

`TS_ENABLE_METRICS`

Enables an unauthenticated Prometheus `/metrics` endpoint.

Use it only when a metrics collector needs it. Metrics can reveal useful network information.

`TS_LOCAL_ADDR_PORT`

Address for the health and metrics endpoints. Default: `[::]:9002`.

The default listens on all interfaces in the shared network namespace. Use a loopback address when tailnet clients should not reach the health or metrics endpoint.

## workload identity and kubernetes

`TS_CLIENT_ID`

OAuth client ID for workload identity. It can be used alone with an automatically provided ID token, with `TS_CLIENT_SECRET`, or with `TS_ID_TOKEN`.

Values beginning with `file:` are read from a file.

`TS_CLIENT_SECRET`

OAuth client secret. Use it with `TS_CLIENT_ID`.

Values beginning with `file:` are read from a file. Do not use it with `TS_ID_TOKEN` or `TS_AUDIENCE`.

`TS_ID_TOKEN`

Identity provider token for workload identity federation. Use it with `TS_CLIENT_ID`.

Values beginning with `file:` are read from a file. Do not use it with `TS_CLIENT_SECRET` or `TS_AUDIENCE`.

`TS_AUDIENCE`

Audience for an automatically requested identity token. Use it with `TS_CLIENT_ID`.

Do not use it with `TS_CLIENT_SECRET` or `TS_ID_TOKEN`.

`TS_KUBE_SECRET`

Kubernetes Secret name used for Tailscale state. It has no use in this Docker Compose setup.

## experimental settings

`TS_EXPERIMENTAL_VERSIONED_CONFIG_DIR`

Directory containing a versioned tailscaled configuration file. This is experimental.

Do not combine it with `TS_AUTHKEY`, `TS_HOSTNAME`, `TS_ROUTES`, `TS_EXTRA_ARGS`, `TS_ACCEPT_DNS`, or workload identity settings.

`TS_EXPERIMENTAL_SERVICE_AUTO_ADVERTISEMENT`

Controls automatic Tailscale Service advertisement for a Serve configuration. It is for newer containerboot releases and may change.

Leave it unset unless using Tailscale Services with `TS_SERVE_CONFIG`.

## normal sidecar setup

For the basic sidecar, these are usually enough:

```sh
HEADSCALE_URL=https://headscale.example.com
TS_HOSTNAME=my-app
TS_AUTH_ONCE=true
TS_USERSPACE=false
TS_ROUTES=
TS_EXTRA_ARGS=
```

Put the auth key in `secrets/authkey.txt`, then run:

```sh
./scripts/up.sh
```
