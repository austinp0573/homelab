# lab-tracker

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### lab-tracker

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-2% | ~40-80 MB | image small; sqlite under ./data | idle |
| expected | 2-8% | ~80-150 MB | sqlite usually MB-scale for a homelab inventory | UI browsing / edits |
| high | 0.2-0.5 core | ~200-400 MB | grows if you store lots of notes/attachments later | bulk import or many concurrent tabs |

browser ui for tracking homelab assets. physical hosts, vms, vps, services,
networks, ups power links, backup jobs, etc.

everything is stored in data/inventory.yml. the ui reads and writes that file.
you can also edit the yaml by hand and hit "reload from disk".

## quick start

```bash
cd services/lab-tracker
cp .env.example .env
./scripts/up.sh
```

open http://127.0.0.1:8791 (or whatever HOST_PORT you set in .env).

stop with:

```bash
./scripts/down.sh
```

scripts pick nerdctl compose or docker compose. override with:

```bash
COMPOSE_CMD="docker compose" ./scripts/up.sh
```

## data

- data/inventory.yml is created on first start if missing
- data/ is gitignored; keep backups yourself
- each successful save copies the previous file to inventory.yml.bak

## notes

- asset names must be unique (case-insensitive)
- deleting a parent clears that id from children; children are not deleted
- if the yaml changed on disk since the ui loaded it, save is rejected until you reload
- secrets fields are optional and stored in plaintext in the yaml if you fill them in


&nbsp;

**466f724a616e6574**
