# prometheus config

deploy as sibling of grafana (often `/opt/prometheus/`), not nested under grafana’s data dir.

## `.env` / compose

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `prometheus` | compose project prefix; keep stable next to grafana’s separate project. nesting this under grafana’s directory is a layout smell — deploy as a sibling. renaming orphans volumes with TSDB data you still need. Renaming mid-flight orphans volumes unless you migrate them on purpose. |
| `CONTAINER_NAME` | `prometheus` | fixed container name for logs and scrape debugging. Grafana’s datasource points at host `:9090`, not this name, but ops still use it constantly. collisions with another prometheus container fail `up`. Proxy backends and smoke scripts often hardcode this string. |
| `NODE_EXPORTER_CONTAINER_NAME` | `node-exporter` | companion exporter container name. scrape config uses compose DNS `node_exporter` (service name), not necessarily this container_name — don’t confuse the two. rename carefully or update prometheus.yml. Fix red targets one job at a time in the Prometheus UI. |
| `RESTART_POLICY` | `unless-stopped` | both prometheus and node-exporter should come back after reboot. a dead TSDB after power loss means blank Grafana until you notice. stop explicitly only for maintenance. Use an explicit stop for maintenance; otherwise expect it back after reboot. |
| `PROMETHEUS_IMAGE` | `prom/prometheus:v3.4.2` | pin; v3 has flag/UI differences from v2. bump with a config check (`promtool` or dry run) before trusting. floating tags on the metrics brain is a bad idea. v3 differs from v2 in flags and UI; validate config before trusting a bump. |
| `NODE_EXPORTER_IMAGE` | `quay.io/prometheus/node-exporter:v1.9.1` | pin the exporter independently of prometheus. version skew is usually fine; breaking changes show up as missing metrics. pull from quay as in the compose, not a random mirror. Update every proxy and smoke script that still points at the old listen. |
| `HOST_BIND` | `127.0.0.1` | both publishes stay on loopback for same-host Grafana. binding `0.0.0.0` exposes Prometheus UI/API to the LAN unauthenticated by default — usually wrong. remote scrapes should use intentional auth/network, not open bind. Loopback plus an edge proxy is the usual safe exposure model. |
| `HOST_PORT` | `9090` | Prometheus UI/API on the host; Grafana datasource defaults here. changing it means updating Grafana provisioning and any reload scripts. conflict with another 9090 is an instant bind error. Change the left-side publish and update every caller in the same commit. |
| `NODE_EXPORTER_HOST_PORT` | `9100` | host publish for debug curls; scrape uses compose DNS `node_exporter:9100` inside the network. publishing is optional for scrape health but useful when debugging from the host. don’t point Grafana at node-exporter directly for dashboards that expect Prometheus. Fix red targets one job at a time in the Prometheus UI. |
| `RETENTION` | `15d` | `--storage.tsdb.retention.time`; older samples drop. longer retention needs disk — watch `DATA_DIR` growth. this is not Loki retention; tune independently. Watch disk growth and treat deletes as irreversible without backup. |
| `DATA_DIR` | `./data` | TSDB on disk; this is the precious state. deleting it loses all history; back it up if long-range graphs matter. keep off slow network mounts if you can. Wipe equals data loss unless you have a restore you have actually rehearsed. |
| `--web.enable-lifecycle` | on | enables `POST /-/reload` for config reload without full restart. without it you’re stuck restarting the container for every scrape job edit. still validate yaml before reload — bad config can brick the process. Fix red targets one job at a time in the Prometheus UI. |
| `extra_hosts` | `host.docker.internal:host-gateway` | lets Prometheus reach host-published metrics (gatus, ntfy, etc.). without this, `host.docker.internal` doesn’t resolve on Linux Docker. don’t use `127.0.0.1` from inside the container for host services — that’s the container itself. Operational detail matters here — verify against the running compose when unsure. |
| node_exporter `pid` | `host` | host PID namespace so process metrics reflect the real machine. without it you mostly see containerized lies. pair with the usual rootfs/sys mounts in compose or host stats are incomplete. Update every proxy and smoke script that still points at the old listen. |

## `config/prometheus.yml`

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `global.scrape_interval` | `30s` | default scrape cadence for jobs that don’t override. lower intervals mean more cardinality pressure and disk; higher means slower alerting. 30s is a sane homelab default — don’t cargo-cult 1s. Tune from measured behavior, not the first number that felt safe. |
| `global.evaluation_interval` | `30s` | rule evaluation cadence; keep near scrape interval unless you have a reason. unused if you have no recording/alerting rules yet, but still set. mismatched intervals make “why didn’t the rule fire” debugging harder. Tune from measured behavior, not the first number that felt safe. |
| job `prometheus` | `localhost:9090` | self-scrape; `localhost` is correct **inside** the prometheus container. this is the exception to the host.docker.internal rule. removing it loses promethean self-metrics useful for debugging the debugger. If this job goes red, Prometheus itself is sick — fix before chasing node_exporter or host.docker.internal targets that look related. |
| job `node` | `node_exporter:9100` | scrape via compose DNS on the shared network. if you rename the service, update this target. host port publish is irrelevant to this job. Fix red targets one job at a time in the Prometheus UI. |
| commented jobs | gatus `:8080`, ntfy `:2586` via `host.docker.internal` | placeholders — enable when those exporters/metrics endpoints exist. wrong ports fail the job red in the UI; that’s useful signal. uncomment one at a time and verify targets. Operational detail matters here — verify against the running compose when unsure. |

**do not** scrape host services as `127.0.0.1` from inside the prometheus container — use `host.docker.internal` or a LAN/tailnet IP.
