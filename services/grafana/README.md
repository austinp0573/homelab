# grafana

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### grafana

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-3% | ~100-200 MB | sqlite + plugins, hundreds of MB | idle UI |
| expected | 5-20% | ~250-500 MB | 1-2 GB comfortable for sqlite + provisioning | a few users loading dashboards |
| high | 0.5-2 cores | ~1-2 GB | grows with dashboards / sqlite | many concurrent dashboards, alerting, image rendering |

deploy paths on host:

- `/opt/grafana/` - this directory (ui)
- `/opt/prometheus/` - `prometheus/` sibling
- `/opt/loki/` - `loki/` sibling

metrics (prometheus + node_exporter), logs (loki + alloy), and the grafana ui. three compose projects on purpose - start and stop them independently.

sqlite for grafana state. no postgres.

## how the pieces talk

each stack publishes on the host loopback:

| thing | default |
| --- | --- |
| grafana | 127.0.0.1:3000 |
| prometheus | 127.0.0.1:9090 |
| node_exporter | 127.0.0.1:9100 |
| loki | 127.0.0.1:3100 |
| alloy http | 127.0.0.1:12345 |

grafana uses `network_mode: host`. that way its provisioned datasources can use `http://127.0.0.1:9090` and `http://127.0.0.1:3100` without a shared docker network or dns between projects.

inside the prometheus compose, prometheus scrapes `node_exporter:9100` over the normal compose network. same idea for alloy -> loki (`http://loki:3100`).

if you drop host networking later, you will need another way for grafana to reach those loopback ports (host-gateway, shared network, etc).

## deploy

order does not matter much. prometheus and loki before grafana if you want the example dashboard to show data on first login.

prometheus:

1. copy `prometheus/` to `/opt/prometheus/`
2. `cp .env.example .env`
3. `./scripts/up.sh`
4. `./scripts/smoke.sh`

loki:

1. copy `loki/` to `/opt/loki/`
2. `cp .env.example .env`
3. `./scripts/up.sh`
4. `./scripts/smoke.sh`

grafana:

1. copy this directory to `/opt/grafana/` (you can omit the `prometheus/` and `loki/` subdirs on the host; those go to `/opt/prometheus` and `/opt/loki`)
2. `cp .env.example .env`
3. set `GF_SECURITY_ADMIN_PASSWORD` to something real before the first start
4. `mkdir -p data` (compose runs as uid 472; if it cannot write, `chown 472:472 data`)
5. `./scripts/up.sh`
6. `./scripts/smoke.sh`

login: `http://127.0.0.1:3000` with the admin user from `.env`.

admin user/password env vars only apply when `data/` is empty. change the password in the ui after that, or wipe `data/` and start over.

## layout

```text
/opt/grafana/
  .env
  compose.yml
  provisioning/
    datasources/datasources.yml
    dashboards/
  data/                 # sqlite + plugins

/opt/prometheus/
  .env
  compose.yml
  config/prometheus.yml
  data/

/opt/loki/
  .env
  compose.yml
  config/loki.yml
  config/config.alloy
  data/
  alloy-data/
```

## ops

each tree has its own scripts:

```sh
./scripts/up.sh
./scripts/smoke.sh
nerdctl compose logs -f
./scripts/down.sh
```

scripts use `nerdctl compose` when present, otherwise `docker compose`.

## plugins

set `GF_INSTALL_PLUGINS` in `.env` to a comma-separated list of plugin ids. grafana downloads them on startup into `data/`.

common ones that are still useful:

- `yesoreyeram-infinity-datasource` - http/json/csv as a datasource (status pages, simple apis)
- `grafana-clock-panel` - clock panel for NOC-style boards

example:

```sh
GF_INSTALL_PLUGINS=yesoreyeram-infinity-datasource,grafana-clock-panel
```

leave it empty if you do not need any. first boot with plugins is slower. core prometheus/loki panels do not need plugins.

## alerting

grafana-native alerting is enough for now. contact points / notification policies live in the ui (or later as provisioning).

wiring alerts to ntfy: `notes/ntfy-alerting.md`.

## auth later

grafana admin login is fine on localhost. when this gets a public hostname, put tinyauth in front and keep grafana auth as a second lock or simplify it - `notes/tinyauth.md`.

haproxy stub: `haproxy/backend.example.cfg` (`grafana.example.com` placeholder).

## resources

rough idle footprint on a small box:

- grafana: a few hundred MB ram
- prometheus + node_exporter: often 200-500 MB depending on series count
- loki + alloy: similar; grows with log volume

retention defaults are short on purpose (prometheus 15d, loki 14d). a small edge VPS can run this, but cardinality and chatty log shipping will hurt first. start with host metrics only, add scrapes slowly.

disk: `data/` dirs. prometheus and loki are the ones that grow.

## what is placeholder vs real

real:

- compose + scripts for all three
- prometheus scraping itself + node_exporter
- loki up, alloy running with a write sink
- grafana datasources + one example dashboard

placeholder / edit later:

- extra prometheus scrape jobs (gatus, ntfy, ...) in `prometheus/config/prometheus.yml`
- alloy log sources in `loki/config/config.alloy`
- `GF_SERVER_ROOT_URL` / haproxy hostname
- admin password (must change before first start)

## related

- `config-explanations.md` - env and config file notes
- `notes/deploy.md` - host-agnostic deploy notes
- `prometheus/README.md`, `loki/README.md` - short per-stack notes


&nbsp;

**466f724a616e6574**
