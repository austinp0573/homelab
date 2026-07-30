# loki

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### loki

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 2-5% | ~200-400 MB | chunks/index: hundreds of MB early on | ingest from alloy |
| expected | 10-40% | ~500 MB-1.5 GB | 1-5+ GB/week common in a small lab, depends on retention | steady log ingest + occasional queries |
| high | 1-2+ cores | ~2-4 GB | retention can push tens of GB | noisy apps / wide LogQL queries |

### alloy

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-3% | ~50-100 MB | config + small WAL | tailing quiet logs |
| expected | 5-15% | ~128-256 MB | tens to hundreds of MB positions/WAL | forwarding container/host logs to loki |
| high | 0.5-1+ core | ~512 MB-2 GB | grows with backlog | log storms (rule of thumb ~1 core / 120 MB per MiB/s) |

deploy path on host: `/opt/loki/`

part of `services/grafana/`. loki + grafana alloy.

alloy is configured to push to loki. log sources are commented placeholders in `config/config.alloy`.

## deploy

1. copy this directory to `/opt/loki/`
2. `cp .env.example .env`
3. `./scripts/up.sh`
4. `./scripts/smoke.sh`

loki: `http://127.0.0.1:3100`

parent notes: `../README.md`, `../config-explanations.md`.


&nbsp;

**466f724a616e6574**
