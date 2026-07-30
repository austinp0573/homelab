# prometheus

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### prometheus

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 2-5% | ~150-300 MB (few targets) | TSDB: plan ~1-5 GB for short retention / few series | scrape pulls every interval |
| expected | 5-20% | ~400 MB-1.5 GB | retention-driven; tens of GB possible | steady scrape + query load |
| high | 1-2+ cores | ~2-8 GB+ with high cardinality | can grow fast with long retention | expensive queries / cardinality spikes |

Memory tracks active series count more than anything else.

### node_exporter

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~10-20 MB | tiny image | prometheus scrape every interval |
| expected | 1-3% | ~15-40 MB | negligible | small metrics payload each scrape |
| high | 5-15% briefly | ~50-100 MB | still small | host with huge mount/fd counts can inflate scrapes |

deploy path on host: `/opt/prometheus/`

part of `services/grafana/`. prometheus + node_exporter only.

## deploy

1. copy this directory to `/opt/prometheus/`
2. `cp .env.example .env`
3. `./scripts/up.sh`
4. `./scripts/smoke.sh`

ui: `http://127.0.0.1:9090` (loopback by default).

edit scrape jobs in `config/prometheus.yml`. reload with `POST /-/reload` or recreate.

parent notes: `../README.md`, `../config-explanations.md`.


&nbsp;

**466f724a616e6574**
