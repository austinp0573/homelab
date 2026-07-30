# loki config

Loki + Alloy. Grafana scrapes Loki on host `127.0.0.1:3100`; Alloy pushes to Loki over the compose network (`http://loki:3100/...`).

## `.env` / compose

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `loki` | compose project for Loki+Alloy as a sibling of Grafana, not nested in grafana data. Stable name keeps volumes and scripts predictable. Renaming without migrating `DATA_DIR` looks like logs disappeared. Keep the name stable so volumes, scripts, and muscle memory stay aligned — Grafana’s datasource still points at the host port regardless of this name, so a rename only breaks ops, not the query URL. |
| `CONTAINER_NAME` | `loki` | Loki container name for logs/exec. Grafana talks to host port, Alloy talks to service DNS `loki` — both matter in different paths. name collisions fail startup. Proxy backends and smoke scripts often hardcode this string. |
| `ALLOY_CONTAINER_NAME` | `alloy` | Alloy agent container; ships logs into Loki. if Alloy is down, Loki stays healthy but empty — check both. don’t confuse Alloy UI port with Loki’s 3100. If Alloy is down, Loki stays healthy but empty — check both. |
| `RESTART_POLICY` | `unless-stopped` | both services should survive reboot. Alloy positions/WAL live in `ALLOY_DATA_DIR` — a missed restart can gap logs. stop only for intentional maintenance. Use an explicit stop for maintenance; otherwise expect it back after reboot. |
| `LOKI_IMAGE` | `grafana/loki:3.4.3` | pin; schema/config keys move across majors. bump with a config review, not blind pull. keep roughly near Grafana’s supported Loki versions. Schema and limit keys move across majors — review loki.yml when bumping. |
| `ALLOY_IMAGE` | `grafana/alloy:v1.8.3` | pin Alloy separately; river/config syntax evolves. old config on new Alloy fails loud at start — read the error. Alloy replaces older promtail patterns in this stack. River syntax evolves; old config fails loud at start on a new Alloy. |
| `HOST_BIND` | `127.0.0.1` | Loki (and Alloy UI) publishes on loopback for Grafana host-net. `0.0.0.0` with `auth_enabled: false` is an open log API — don’t. remote shippers should use intentional network paths. Loopback plus an edge proxy is the usual safe exposure model. |
| `HOST_PORT` | `3100` | Loki HTTP for Grafana datasource. change means updating Grafana provisioning. Alloy does **not** use this host port — it uses compose DNS. Change the left-side publish and update every caller in the same commit. |
| `ALLOY_HOST_PORT` | `12345` | Alloy UI/metrics on the host for debugging pipelines. not required for log shipping to work. leave loopback-bound; it’s an admin surface. Update every proxy and smoke script that still points at the old listen. |
| `DATA_DIR` | `./data` | Loki filesystem storage (chunks/index). growth follows ingest + retention; disk-full takes down writes. back up only if you care about historical logs (often you don’t). Wipe equals data loss unless you have a restore you have actually rehearsed. |
| `ALLOY_DATA_DIR` | `./alloy-data` | positions/WAL so restarts don’t fully re-ship or lose place. deleting it can re-read files from the start or skip depending on source — treat as state. keep writable by the Alloy user. Watch disk growth and treat deletes as irreversible without backup. |
| alloy listen | `0.0.0.0:12345` | hardcoded in command inside the container; host publish still controlled by `HOST_BIND`. opening the publish bind exposes this UI. use for pipeline debug, not as a public endpoint. Edit the compose/config that owns it — .env alone will not move hardcoded values. |
| `/var/log` mount | commented | enable together with file scrape in Alloy when you want host syslog/journal files. mounting without scrape config does nothing; scrape without mount fails. prefer docker/journal sources consciously — don’t enable blind. Fix red targets one job at a time in the Prometheus UI. |

## `config/loki.yml`

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `auth_enabled` | `false` | multi-tenant auth off — OK only on loopback / trusted net. do not expose publicly like this or anyone can push/query. enabling later needs tenant headers everywhere — plan before opening the bind. Operational detail matters here — verify against the running compose when unsure. |
| `server.http_listen_port` | `3100` | Loki HTTP listen inside the container; mapped via compose. Grafana and Alloy both depend on this staying consistent. changing requires compose + clients update. Update every proxy and smoke script that still points at the old listen. |
| `server.grpc_listen_port` | `9096` | internal gRPC; usually leave alone for single-node. conflicts are rare unless you pack many services. don’t publish this unless you know why. Update every proxy and smoke script that still points at the old listen. |
| `server.log_level` | `info` | Loki process logs; `debug` is noisy but useful for ingest rejects. not related to application logs you store. dial back after debugging. Operational detail matters here — verify against the running compose when unsure. |
| `common.instance_addr` | `127.0.0.1` | instance address for single-node common config. wrong values mostly matter in clustered setups you don’t have here. leave default unless upstream docs say otherwise for your mode. Operational detail matters here — verify against the running compose when unsure. |
| `common.path_prefix` | `/loki` | path prefix for Loki’s HTTP routes. clients usually hit `/loki/api/v1/...` as Alloy does. don’t strip this in a reverse proxy without rewriting. Operational detail matters here — verify against the running compose when unsure. |
| `common.storage.filesystem.chunks_directory` | `/loki/chunks` | chunk files on the container FS (under mounted data). if the mount isn’t writable, ingests fail. wiping chunks without index consistency = broken queries. Watch disk growth and treat deletes as irreversible without backup. |
| `common.storage.filesystem.rules_directory` | `/loki/rules` | ruler storage path; unused until you define rules. still needs to exist/be writable. not where Alloy config lives. Ignore this until the template actually wires it through. |
| `common.replication_factor` | `1` | single-node; higher values need a real cluster. setting >1 alone doesn’t create replicas — it just breaks writes. keep at 1 for this homelab layout. Operational detail matters here — verify against the running compose when unsure. |
| schema | tsdb / filesystem / v13 / 24h index | from `2020-10-24` — don’t casually change period/schema on an existing store. schema migrations are a whole project. new periods append; wrong edits brick queries. Operational detail matters here — verify against the running compose when unsure. |
| `limits_config.reject_old_samples` | `true` | drops samples older than max age — protects against bad clocks and replay bombs. if hosts have skewed time, logs vanish mysteriously. fix NTP before disabling this. Operational detail matters here — verify against the running compose when unsure. |
| `limits_config.reject_old_samples_max_age` | `168h` | 7d max age for accepted samples. backfilling older than this needs a temporary raise. not the same as retention_period. Operational detail matters here — verify against the running compose when unsure. |
| `limits_config.retention_period` | `336h` | **14d** query retention target. without compactor retention enabled, this does little. shorter saves disk; longer needs space planning. Watch disk growth and treat deletes as irreversible without backup. |
| `limits_config.allow_structured_metadata` | `true` | allows structured metadata on streams (modern Loki). disabling can break Alloy/clients that emit it. leave on unless you hit compatibility issues. Operational detail matters here — verify against the running compose when unsure. |
| `limits_config.volume_enabled` | `true` | enables volume/usage endpoints useful in Grafana. off mainly if you hit perf issues on tiny hardware. not required for basic LogQL. Watch disk growth and treat deletes as irreversible without backup. |
| `compactor.retention_enabled` | `true` | required for retention to actually delete data. retention_period without this is a paper promise. watch disk after enabling on an old fat store — deletes lag by delay settings. Watch disk growth and treat deletes as irreversible without backup. |
| `compactor.compaction_interval` | `10m` | how often compactor runs; lower is snappier cleanup/CPU. fine at 10m for homelab. don’t set seconds-level on a Pi for fun. Tune from measured behavior, not the first number that felt safe. |
| `compactor.retention_delete_delay` | `2h` | grace before deletion after marking; safety against oops. Shorter frees disk faster; longer lets you recover mistakes. Retention is not instantaneous gone the moment the period elapses. Watch disk growth and treat deletes as irreversible without backup — lowering this after a fat store will not reclaim space until the next compaction cycles finish. |
| `analytics.reporting_enabled` | `false` | disables Loki phone-home. leave off for private labs. unrelated to your metrics/log pipelines. Update every proxy and smoke script that still points at the old listen. |

## `config/config.alloy`

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `logging.level` | `info` | Alloy’s own process logs. bump to debug when a pipeline component is silent. too verbose forever fills docker logs. Operational detail matters here — verify against the running compose when unsure. |
| `logging.format` | `logfmt` | structured-ish Alloy logs; easier to grep than json for quick SSH debug. change if your log shipper prefers json. doesn’t affect app logs you collect. Operational detail matters here — verify against the running compose when unsure. |
| `loki.write` endpoint | `http://loki:3100/loki/api/v1/push` | push URL over compose DNS — correct from Alloy’s network. pointing at `127.0.0.1:3100` from Alloy usually fails (wrong namespace). Grafana queries Loki separately; this is write-only path. Use the name clients actually type, not a container-local address. |
| file / docker sources | commented | **no logs shipped** until you enable them — empty Loki is expected out of the box. uncomment/configure sources deliberately (docker socket perms, path mounts). enabling everything at once is how you ingest noise and blow retention. Operational detail matters here — verify against the running compose when unsure. |
