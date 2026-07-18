# nft-gui env

static nftables config builder UI. does **not** inspect, validate against, or apply the host firewall — browser storage + export only.

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `nft-gui` | also local image `${name}:local` built from this directory. renaming changes the expected image tag for `up.sh` flows. keep stable once scripted. Renaming mid-flight orphans volumes unless you migrate them on purpose. |
| `CONTAINER_NAME` | `nft-gui` | fixed name for logs and proxy backends. the app never talks to host nftables — naming won’t grant privileges. collisions fail create. Proxy backends and smoke scripts often hardcode this string. |
| `RESTART_POLICY` | `unless-stopped` | UI comes back after reboot; your drafts live in browser storage unless you exported. don’t confuse container restart with firewall state — there is none applied. Use an explicit stop for maintenance; otherwise expect it back after reboot. Export anything you care about before a recreate — browser storage is not the container volume. |
| `HOST_BIND` | `127.0.0.1` | loopback by default; `0.0.0.0` only if intentional LAN access. there’s no auth in this UI — treat exposure like a config editor on the network. edge gate if you publish wider. Loopback plus an edge proxy is the usual safe exposure model. |
| `HOST_PORT` | `8787` | → container `:80`. change on conflict and update bookmarks/proxies. healthcheck hits container localhost:80, not the host port. Change the left-side publish and update every caller in the same commit. |

`nginx.conf` is build-time (CSP / cache headers). always `nft --check --file …` on the target before apply.
