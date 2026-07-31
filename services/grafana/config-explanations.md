# config explanations

three stacks. each has its own `.env` and compose file.

---

## grafana `.env`

`GF_SERVER_HTTP_ADDR` / `GF_SERVER_HTTP_PORT` - listen address with `network_mode: host`. default loopback so the ui is not on the lan.

`GF_SERVER_ROOT_URL` / `GF_SERVER_DOMAIN` - what grafana thinks its public url is. matters for redirects, alerts, and some links. keep the localhost values until haproxy is real, then set them to `https://grafana.example.com`.

`GF_SECURITY_ADMIN_USER` / `GF_SECURITY_ADMIN_PASSWORD` - bootstrap only. applied when the sqlite db is first created under `data/`. changing `.env` later does nothing to an existing admin.

`GF_USERS_ALLOW_SIGN_UP` - leave false.

`GF_AUTH_ANONYMOUS_ENABLED` - leave false.

`GF_INSTALL_PLUGINS` - comma-separated plugin ids, or empty. see README.

`DATA_DIR` - grafana sqlite, sessions, downloaded plugins.

---

## grafana provisioning

`provisioning/datasources/datasources.yml` - prometheus + loki. urls are host loopback because grafana is on the host network.

`provisioning/dashboards/` - file provider loads json from `dashboards/json/`. the example board is a starting point; edit in the ui (`allowUiUpdates: true`) or replace the json.

---

## prometheus `.env`

`HOST_BIND` / `HOST_PORT` - published prometheus ui/api. keep 127.0.0.1 unless you know you want it elsewhere.

`NODE_EXPORTER_HOST_PORT` - published node_exporter. mainly for curl/debug; prometheus scrapes the compose service name.

`RETENTION` - passed as `--storage.tsdb.retention.time`. default `15d`.

`DATA_DIR` - tsdb.

---

## `prometheus/config/prometheus.yml`

`scrape_interval: 30s` - calm default.

jobs:

- `prometheus` - self
- `node` - `node_exporter:9100` on the compose network

commented jobs are examples for other homelab services. from inside the prometheus container, host-published ports are not `127.0.0.1` - use `host.docker.internal` (compose already adds host-gateway) or the host lan ip.

reload after edits:

```sh
curl -X POST http://127.0.0.1:9090/-/reload
```

(`--web.enable-lifecycle` is on)

---

## loki `.env`

`HOST_PORT` - loki http api (grafana datasource target).

`ALLOY_HOST_PORT` - alloy's own http listen (debug ui / metrics). not required for grafana.

`DATA_DIR` - loki chunks/index.

`ALLOY_DATA_DIR` - alloy positions / wal.

---

## `loki/config/loki.yml`

single-process filesystem storage. `retention_period: 336h` (14d) with compactor retention enabled.

`auth_enabled: false` - fine while bound to loopback. do not publish loki on a public interface like this.

---

## `loki/config/config.alloy`

alloy runs with a `loki.write` pointing at `http://loki:3100`. log sources are commented examples. uncomment and mount `/var/log` (or add docker discovery) when you actually want logs in grafana.
