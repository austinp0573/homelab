# sidecar

caddy in the same compose project as one app. caddy is what you publish; the app stays on the internal network.

no dummy app service here - point `reverse_proxy` at whatever container name you add (or an external network).

## notes

- app is not published on the host. only caddy ports are.
- put both services on the default compose network (or a named one) and use the service name as the upstream.
- for a single hostname this is usually enough. for many hosts, prefer `edge/`.

copy `scripts/` from `../../template/` if you want the usual up/down/smoke helpers.


&nbsp;

**466f724a616e6574**
