# tailscale env

sidecar compose under `compose/`. app uses `network_mode: service:tailscale`. prefer `secrets/authkey.txt` over `TS_AUTHKEY` in `.env`.

## naming / publish

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `tailscale-sidecar` | Compose project for the sidecar + sample app pair. Stable naming keeps the `ts-state` volume attached across recreates — that volume is the node identity. Renaming projects is how you accidentally create a second Tailscale node with a new auth. Treat this as the unit of "one sidecar identity". |
| `TS_CONTAINER_NAME` | `tailscale` | Tailscale/containerboot container name. The app uses `network_mode: service:tailscale`, so this name is the network namespace anchor. Rename both carefully or the app loses netns. Exec for `tailscale status` goes here, not into the app container. |
| `APP_CONTAINER_NAME` | `tailscale-app` | Workload container sharing Tailscale's netns. It has no independent network stack — ports, firewall, and tailnet IP are the sidecar's. Restarting Tailscale disrupts the app path. Replace the sample nginx with your real service but keep the netns join. |
| `TAILSCALE_IMAGE` | `tailscale/tailscale:latest` | Official image; pin a digest/tag for repeatability in anything you care about. `latest` moves and has surprised me on containerboot env behavior. Pull consciously when you want upgrades. Same image family works for Headscale login-server mode. |
| `APP_IMAGE` | `nginx:alpine` | Placeholder app image proving the sidecar pattern. Replace with your real workload image before calling this a deployment. The sample listens on `:80` inside the shared netns. Forgetting to replace it is why "the sidecar works" but your app never shipped. |
| `RESTART_POLICY` | `unless-stopped` | Both containers should return after reboot with the same tailnet identity (state volume). Stopping only the app leaves a lonely tailscale node; stopping only tailscale orphans the app netns. Use deliberate `down` when rotating auth keys. After a forced `down`, bring Tailscale up before the app so the shared netns exists cleanly. |
| `HOST_PORT` | `8080` | Publishes the shared-netns app port `:80` to the host. Useful for local smoke; remove `ports:` entirely for tailnet-only exposure. Publishing wide plus an open ACL is double exposure. Host port collisions are independent of the tailnet IP. |
| `COMPOSE_CMD` | `nerdctl compose` | Script override for compose invocations on this host. Keep aligned with how you run other stacks. Wrong engine may not support the same secret/mount quirks. Optional if you always run compose by hand. |

## identity / login

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `HEADSCALE_URL` | *(empty)* | Empty means Tailscale SaaS control plane. Non-empty makes `up.sh` add `--login-server=` for Headscale. Wrong URL auths to the wrong coordination server and looks like key rejection. Include scheme; trailing slash issues are less common than forgetting https. |
| `TS_AUTHKEY` | `<secret>` / empty | Auth key fallback if `secrets/authkey.txt` is missing. Prefer the file so `.env` stays non-secret. Reusable preauth keys with tags are the usual sidecar pattern. Expired/one-time keys fail on fresh state but not on existing state volume. |
| `TS_AUTH_ONCE` | `true` | containerboot only logs in when state is empty. That is what you want with a persistent `ts-state` volume. `false` re-auths more aggressively and can burn one-time keys. Flip only when deliberately forcing re-register. |
| `TS_HOSTNAME` | `sample-app` | Node name advertised on the tailnet. Change from `sample-app` before you have five nodes named that. DNS/MagicDNS neighbors use this. Renaming later is possible but messy in ACLs and habit. |
| `TS_STATE_DIR` | `/var/lib/tailscale` | In-container path for Tailscale state; named volume `ts-state` mounts here. This directory is the identity — wipe it and you get a new node. Do not change the path without updating the volume mount. Back up if the node is precious; usually re-auth is easier. |
| `TS_USERSPACE` | `false` | `false` = kernel TUN path needing `privileged` + `/dev/net/tun`. `true` = userspace networking, slower, different feature limits (serve/egress proxies disagree). Lab default is kernel for fewer surprises. Flipping after first run needs a recreate and mental reset. |

## routes / flags

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `TS_ROUTES` | *(empty)* | Comma-separated CIDRs to advertise as subnet routes. Empty = no router. Approval in ACL/admin + host IP forwarding are both required or the routes stay useless. Advertising your LAN without intent is a security footgun. |
| `TS_EXTRA_ARGS` | *(empty)* | Extra flags passed to `tailscale up`. Use for one-offs like `--accept-routes` or `--ssh` not covered by dedicated vars. `up.sh` may also fold tags/login-server into this path — do not duplicate flags. Bad flags prevent up and leave the node half-joined. |
| `TS_ADVERTISE_TAGS` | *(empty)* | `up.sh` turns this into `--advertise-tags=`. Tags must exist in ACL/policy or the node is sad. Prefer tags on preauth keys plus this for clarity. Empty is fine for personal single-user SaaS. |
| `TS_ADVERTISE_EXIT_NODE` | `false` | When `true`, adds `--advertise-exit-node`. Still needs admin approval and is a big trust decision. Do not enable on a random app sidecar. Exit node ≠ subnet router; set the one you mean. |
| `TS_TAILSCALED_EXTRA_ARGS` | *(empty)* | Flags for `tailscaled` itself (verbosity, etc.), not `tailscale up`. Useful for debug, noisy if left on. Wrong daemon flags can prevent TUN init. Keep empty in normal operation. |

## optional containerboot

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `TS_ACCEPT_DNS` | unset (off) | When `true`, MagicDNS/resolv changes apply inside the shared netns — the app sees them too. That can break resolution of local Docker names if you were relying on them. Leave off unless the app must use tailnet DNS names. Test DNS after enabling. |
| `TS_DEST_IP` | unset | L3 proxy/destination mode for containerboot. Incompatible with userspace and with serve-style setups. Only set if you know you want that forwarding mode. Mis-set values blackhole app traffic in confusing ways. |
| `TS_SOCKS5_SERVER` | unset | e.g. `:1055` to expose a SOCKS5 proxy in the netns. Useful for debugging egress via the tailnet. Do not confuse with the app listen port. Bind carefully; proxies are abuse magnets if exposed. |
| `TS_OUTBOUND_HTTP_PROXY_LISTEN` | unset | HTTP proxy listen addr for outbound via Tailscale. Not your APP_IMAGE port. Same caution as SOCKS — optional lab tooling. Leave unset for normal sidecar-behind-app patterns. |
| `TS_SOCKET` | unset | Override path to `tailscaled.sock`. Default is fine for this compose. Only set when mounting the socket elsewhere for a sidecar-of-sidecar trick. Wrong path breaks CLI and health. |
| `TS_SERVE_CONFIG` | unset | Path to serve/funnel config JSON; needs a directory mount. Powerful and easy to expose the wrong thing. Prefer HAProxy/Caddy on edge over Tailscale serve unless you mean it. Empty keeps serve off. |
| `TS_ENABLE_HEALTH_CHECK` | unset | When enabled, exposes `/healthz` after the node has an IP. Useful for orchestration probes. Needs `TS_LOCAL_ADDR_PORT` awareness. Do not publish health widely without ACLs. |
| `TS_ENABLE_METRICS` | unset | Prometheus `/metrics` via containerboot. Same listen controls as health. Scrape from a trusted collector only. Leaving both health and metrics on a public bind is unnecessary surface. |
| `TS_LOCAL_ADDR_PORT` | unset | Listen addr for health/metrics; image default often `[::]:9002`. Set explicitly when scraping. Dual-stack surprises happen with `[::]` vs `127.0.0.1`. Coordinate with host firewall. |
| `TS_TAILNET_TARGET_IP` / `TS_TAILNET_TARGET_FQDN` | unset | Egress proxy targets; mutually exclusive; not for userspace mode. Used when this container forwards toward another tailnet node. Wrong target fails quietly from the app's POV. Leave unset for the common "app shares netns" pattern. |
| `TS_CLIENT_ID` / `TS_CLIENT_SECRET` / `TS_ID_TOKEN` / `TS_AUDIENCE` | `<secret>` / unset | OAuth / workload identity login alternatives to auth keys. `file:` prefix supported for secret injection. Unused in the simple preauth-key lab path. Do not mix half OAuth + half authkey without reading containerboot docs. |
| `TS_KUBE_SECRET` | unset | Kubernetes secret integration — unused on this compose-on-host layout. Setting it does nothing useful here and confuses future readers. Leave unset. Use authkey/file or OAuth env on this host path instead of inventing a fake kube secret name. |
| `TS_EXPERIMENTAL_*` | unset | Versioned config dir / service auto-advertisement experiments. Behavior changes across image versions. Avoid until you are chasing a specific feature. Prefer stable env knobs above. |

kernel path needs `privileged: true` + `/dev/net/tun`. see `compose/config-explanations.md` for longer prose.
