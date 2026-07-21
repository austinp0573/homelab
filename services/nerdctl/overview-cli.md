# nerdctl cli

Docker-compatible CLI for containerd. Alpine notes prefer `apk add nerdctl buildkit` over the github full tarball. most lab scripts: `nerdctl compose …`. pin awareness: tree mentions `2.3.4` in the release install script.

## global flags

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `--address` | containerd socket | Target containerd API socket; optionally `unix://…`. Wrong socket talks to a different/empty engine — “no containers” false alarm. `-a`/`-H`/`--host` are deprecated aliases still seen in old notes. Rootful vs rootless sockets differ. |
| `--namespace` | `default` | containerd namespace isolation. k8s pods live in `k8s.io` — listing the wrong ns looks empty. `-n` deprecated alias. Lab compose usually stays in `default`. Mixing namespaces dual-manages the same names poorly. |
| `--snapshotter` | platform default | Storage snapshotter backend. `--storage-driver` is deprecated alias. Wrong snapshotter breaks pulls/runs with cryptic errors. Leave default unless you intentionally run zfs/btrfs setups. |
| `--cni-path` | `/opt/cni/bin` | Or `$CNI_PATH`. Missing plugins = network create/run failures. Alpine packages may place binaries elsewhere — align path. Affects compose networks too. |
| `--cni-netconfpath` | `/etc/cni/net.d` | Or `$NETCONFPATH`. Stale conf files here haunt you after manual edits. Permissions matter. Compose-created nets drop configs here. |
| `--data-root` | e.g. `/var/lib/nerdctl` | nerdctl state directory (not all of containerd). Pointing at a half-migrated disk confuses labels/names. Backup rarely needed; space fill breaks creates. Do not point two nerdctl majors at the same data-root and expect compatible metadata. |
| `--cgroup-manager` | `cgroupfs` / `systemd` / `none` | How containers are cgrouped. Mismatch with how the host runs systemd slices causes start failures. `none` is niche/debug. Pick one per host and stick to it. |
| `--insecure-registry` | off | Skip HTTPS verify + allow plain HTTP registries. Only when you mean it (lab registry). Easy to leave on and never notice MITM risk. Prefer proper certs. |
| `--host-gateway-ip` | *(unset)* | What `host-gateway` resolves to in `--add-host`. Unset uses nerdctl’s detected host IP — wrong on multi-homed hosts. Set explicitly when `host.docker.internal` style links fail. Pick the interface that can reach the published host services you scrape; the “first” detected IP is often a VPN/tailnet address that containers cannot use the way you expect. |
| `--userns-remap` | *(unset)* | Rootful idmap remap. **Not** supported for build. Misuse breaks volume permissions. Leave unset unless you know the uid map. |

## compose (what the stacks use)

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `-f, --file` | `compose.yml` / `docker-compose.yml` | Alternate compose file; repeatable for overrides. Wrong file ups an empty/old stack. Lab prefers `compose.yml`. Order matters with multiple `-f`. |
| `-p, --project-name` | directory name / `COMPOSE_PROJECT_NAME` | Isolates multiple stacks. Changing orphans old containers under the previous name. Scripts often hard-code `-p`. Keep stable per deploy dir. |
| `--project-directory` | compose file dir | Alternate cwd for relative paths/env. Mismatch breaks `./data` binds. Useful when compose file lives outside the tree. Set deliberately. |
| `--profile` | *(none)* | Enable compose profiles (`live`, `auth`, `tools`, …). Forgetting `--profile live` is why standby VW “isn’t there”. Multiple profiles allowed. Default services still start. |
| `--env-file` | `.env` | Alternate env file for interpolation. Does not replace `env_file:` inside services unless also wired. Wrong file = wrong ports/secrets interpolated. This is compose-cli interpolation, separate from a service's `env_file:` list. |
| `--ipfs-address` | local IPFS | nerdctl-specific; unused here. Leave default. Ignore unless you pull via IPFS. Leave alone in this lab — none of the stacks pull via IPFS. |

### `compose up`

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `-d, --detach` | off | Background. Conflicts with `--abort-on-container-exit`. Lab scripts almost always `-d`. Foreground mode dies when you Ctrl-C the compose process. |
| `--force-recreate` | off | Recreate even if config unchanged. Use after web-push / secret mount changes that compose does not detect. Heavier than restart. Drops container-local state not in volumes. |
| `--no-recreate` | off | Keep existing containers even when config changed — dangerous when you think you applied env. Useful for surgical updates. Opposite of force-recreate. If you needed config changes applied, this flag fights you; drop it and recreate. |
| `--build` | off | Build images before start. Needed for gen-* local tags. Slow on first run. Fails if buildkitd is down. |
| `--no-build` | off | Never build missing images — fail instead. Good for prod hosts that should only pull. Opposite of `--build`. Pair with pre-pulled/pinned images so missing tags fail loudly instead of building. |
| `--pull` | *(policy)* | `always` / `missing` / `never`. `always` surprises with floating tags. `never` breaks first deploys. Prefer `missing` + pinned tags. |
| `--remove-orphans` | off | Drop containers for services removed from the file. Can delete a container you still wanted if the file was wrong. Safe after intentional service removals. Review `compose ps` first so an edited file does not delete a container you still want. |
| `--scale SERVICE=N` | compose `scale` | Override replica count. Many lab services are not safe to scale (SQLite). HAProxy backends may not follow. Use sparingly. |
| `--quiet-pull` | off | Less pull progress noise in cron logs. No functional change. Handy in scripts. Does not change pull policy — only the progress spam. |
| `--abort-on-container-exit` | off | Stop all if one exits; not with `-d`. Useful for linked one-shot stacks. Painful for long-lived + sidecar mixes. Incompatible with detached mode; choose one failure model for the stack. |

### `compose down` / `stop` / `rm` / `run` / `exec` / `logs` / `ps` / `config`

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `down -v, --volumes` | off | **Deletes named + anonymous volumes** — data loss. Plain `down` keeps named volumes. Never muscle-memory `-v` on VW/DB stacks. Double-check project name first. |
| `down --remove-orphans` | off | Also remove orphan containers for this project. Safer than `-v`. Useful after renames. Does not delete volumes alone. |
| `stop -t, --timeout` | `10` | Seconds before SIGKILL. Too low kills DB mid-flush. Raise for Postgres/MySQL. Does not affect `down` kill path the same on all versions — verify. |
| `rm -f, --force` | off | No confirm (≠ `nerdctl rm -f` semantics exactly). Still needs containers stopped unless combined with `-s`. Easy to remove the wrong service name. Force skips the confirm prompt, not the need for a correct project/service name. |
| `rm -s, --stop` | off | Stop before remove. Prefer over raw rm on running services. Pair with `-f` in scripts. Cleaner than kill+rm when a service is wedged but still listed as running. |
| `rm -v, --volumes` | off | Remove anonymous volumes with the container. Named volumes usually spared — still verify. Dangerous around DB services. Anonymous volumes die; named DB volumes usually survive — verify before assuming either. |
| `run --rm` | off | One-shot cleanup (restic-style). Without `--rm`, exited one-shots clutter `ps -a`. Default user/env come from the service definition. Default for restic one-shots in this tree so `ps -a` stays readable. |
| `run -d` | off | Detach a one-off. Rarely what you want for restic jobs — logs harder. Prefer foreground for backups. Detached one-offs hide restic errors unless you immediately follow logs. |
| `run --no-deps` | off | Don’t start dependencies. Good when DB already up; bad when you forgot redis. Speeds iteration. Great when iterating on app config against an already-healthy db/redis. |
| `run --entrypoint` | image ENTRYPOINT | Override entrypoint for debug shells. Breaks health assumptions. Quote args after `--`. After override, you own signal handling and the process name in `ps`. |
| `run -e / -v / -u / -w / --publish` | — | Env, volume, user, workdir, ports for one-offs. `-v` can escape the service’s declared mounts — careful. Publish on run is easy to leave open. One-off `-v` binds can shadow the service's normal mounts — check paths twice. |
| `run --service-ports` | off | Map the service’s ports on run. Needed when testing a service one-off with published ports. Without it, ports from compose may not bind. Without it, `compose run` often does not publish the ports from the service spec. |
| `exec -i / -t / -T` | TTY on by default | `-T` disables TTY for scripts. Missing `-i` breaks piped input. CI should use `-T`. Scripts should prefer `-T`; interactive rescue shells want `-it`. |
| `exec -u / -w / -e` | — | User, workdir, env for exec. Wrong `-u` cannot read app files. `-e` does not persist. Match the app user when writing into bind-mounted data dirs. |
| `exec --privileged` | off | Elevates the exec session. Needed for some network/debug tools. Do not leave as habit on VW. Opens a large hole for that shell session — drop it when the debug is done. |
| `exec --index` | `1` | Which replica when scaled. Default first replica. Easy to exec the wrong instance. Only matters when the service is scaled above one replica. |
| `logs -f` | off | Follow. Ctrl-C leaves containers running (unlike foreground up). Pair with `--tail`. Follow does not restart the service if it dies — pair with `ps` when debugging crashloops. |
| `logs --tail N` | all | Limit history; `all` can flood. Use `100`/`1000` in incidents. Applies per container. Start with a small N in incidents so you are not drowned in historical noise. |
| `logs --timestamps` | off | Add timestamps — helpful when correlating with host journal. Slightly noisier. Aligns with host journal timestamps when correlating proxy and app failures. Cross-check against neighboring rows before changing logs --timestamps alone. |
| `ps -a` | running only | `-a` includes exited one-shots. Without it, failed restic runs look “gone”. Exited one-shots and failed health recreates only show up with `-a`. Cross-check against neighboring rows before changing ps -a alone. |
| `ps -q` | off | IDs only — good for scripting. Easy to pipe into `rm` disasters. IDs-only output is for pipelines; humans should use normal `ps`. Cross-check against neighboring rows before changing ps -q alone. |
| `ps --services` | off | Service names rather than containers. Handy for loops. Useful to feed into loops over service names rather than container ids. Cross-check against neighboring rows before changing ps --services alone. |
| `config --services` / `--volumes` / `--hash` | — | Validate / list interpolated config. `-q` quiet. Use before up when env feels wrong. Hash detects changes. |

args that look like flags after the service name: use `--` if parsing fights you (`compose run app -- ls --all`).

## `run` (standalone) — flags we actually hit

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `-d, --detach` | off | Background container. You lose immediate logs. Prefer for long services, not debug. Detached standalone runs need an explicit `--name` if you plan to `logs` them later. |
| `-i / -t` | off | Interactive TTY. Need both for real shells. Breaks in non-TTY CI without care. Without a TTY, password prompts and pagers misbehave — expect weirdness over raw pipes. |
| `--rm` | off | Remove on exit — keep one-shots tidy. Opposite of leftover `Exited` clutter. Always for throwaway debug containers so the name is free next time. Cross-check against neighboring rows before changing --rm alone. |
| `--restart` | `no` | `always` / `on-failure` / `unless-stopped`. Lab one-shots stay `no`. Daemons use `unless-stopped`/`always`. One-shot backup containers must stay `no` or a failing job restart-loops forever. |
| `--pull` | `missing` | Pull policy for the image. `always` on `:latest` is surprise city. Pin tags and keep `missing` unless you intentionally want floating updates. Cross-check against neighboring rows before changing --pull alone. |
| `--network` / `--net` | `bridge` | `host`, `none`, `container:…`, CNI name; **repeatable** (unlike docker). Wrong net = DNS miss to siblings. host net for Tailscale/scan paths. Repeatable nets are a nerdctl-ism — do not assume docker compose parity. |
| `-p, --publish` | — | Host ports. Binding `0.0.0.0` exposes widely. Prefer loopback + proxy. Conflicts fail start. |
| `--add-host host:ip` | — | `ip` may be `host-gateway`. Used for `host.docker.internal` style. Wrong IP = silent wrong backend. Without this on Linux, Prometheus/Gatus-style scrapes to host-published ports never resolve — pair with `--host-gateway-ip` when the auto-detected gateway is the wrong NIC. |
| `--device` | — | e.g. `/dev/kfd`, `/dev/dri`, `/dev/net/tun`. Missing device = GPU/TUN failures. Permissions on the node matter. |
| `--privileged` | off | Broad capabilities — Tailscale TUN path, etc. Avoid on untrusted images. Hard to reason about. Required for some TUN paths; treat as a smell on anything facing the internet. |
| `--pid=host` | off | Share host PID ns — node_exporter style. Leaks host process visibility into the container. Needed for node_exporter-style views; avoid on app containers. Cross-check against neighboring rows before changing --pid=host alone. |
| `--gpus` / devices | — | GPU stacks; see compose files. Wrong runtime = CUDA not found. nerdctl/gpu wiring is host-specific. Requires the NVIDIA/AMD runtime bits installed on the node, not just the flag. |
| `-v` / `--volume` | — | Binds / named vols. `:ro` for sources you must not mutate. UID mismatch = EACCES. Prefer named volumes for DB data and binds for config you edit from the host. |
| `--name` | random | Stable name for scripts. Collision fails create. Stable names make HAProxy upstream snippets and scripts boring in a good way. Cross-check against neighboring rows before changing --name alone. |
| `-e` / `--env-file` | — | Env injection. `--env-file` easy to point at secrets — keep modes tight. `-e` overrides. This is compose-cli interpolation, separate from a service's `env_file:` list. |
| `--user` | image user | Run as uid:gid. Mismatch with bind mounts breaks writes. Numeric `uid:gid` avoids depending on passwd entries inside minimal images. Cross-check against neighboring rows before changing --user alone. |
| `--entrypoint` | image | Override entrypoint. Debug tool. Remember CMD still appends unless replaced. Replacing entrypoint often means you must also supply a full command argv. |
| `--platform` | host | Multi-arch pull/run. Wrong platform pulls unusable images on ARM/x86 mixes. Set explicitly on mixed amd64/arm64 fleets or pulls surprise you. Cross-check against neighboring rows before changing --platform alone. |

full run flag surface is huge (resources, security opts, …) — see upstream `command-reference.md` when needed.

## network / volume (scripts)

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `network create NAME` | — | e.g. `llm-backend`, `edge-apps` (external nets for stacks). Create before compose that marks `external: true`. Duplicate create fails — ignore/ok in scripts carefully. Subnet clashes break create. |
| `network ls` / `inspect` / `rm` / `prune` | — | Inspect before rm. `prune` is destructive to unused nets — can surprise. rm fails if containers still attached. Prune only after `compose down` for projects you intend to drop. |
| `volume create` / `ls` / `inspect` / `rm` / `prune` | — | Same caution. `prune` deletes unused volumes — data loss. Always `inspect` before `rm`. Named volumes survive `compose down` without `-v`. |

## buildkit (`/etc/buildkit/buildkitd.toml` on Alpine)

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `[worker.oci] enabled` | `false` | Alpine note: disable OCI worker so only containerd worker runs. Both enabled = confusing dual workers. Restart buildkitd after edits. Alpine lab hosts keep this false so buildkitd has a single worker story. |
| `[worker.containerd] enabled` | `true` | Use containerd as the build worker — matches nerdctl. False leaves builds broken if OCI also false. Keep true on these hosts. Must stay true or `nerdctl build`/`compose build` has nowhere to run. |
| `namespace` | `default` | Must match what nerdctl uses or builds land where runs cannot see them. Wrong ns = “image not found” after successful build. Mismatch with nerdctl's namespace is the classic 'build succeeded, run cannot see image' bug. Cross-check against neighboring rows before changing namespace alone. |

services: `containerd` + `buildkitd` enabled/started. release-full install also wants `ca-certificates`, `cni-plugins`, `iptables`, musl. notes still say figure out nftables vs bundled iptables later.
