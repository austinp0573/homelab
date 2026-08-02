# Actual-Budget

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### actual_server

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~40-60 MB | image ~150 MB + empty data | idle |
| expected | 1-5% | ~50-100 MB | budget files usually KB-MB each | sync when clients open / save |
| high | 0.2-0.5 core | ~200-300 MB | grows with attachments / history | bank sync jobs or many devices syncing |

### frpc

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~10-25 MB | tiny binary / config | control channel idle |
| expected | 1-5% | ~20-40 MB | config only | follows tunneled app traffic |
| high | 0.1-0.5 core | ~64-128 MB | still small | fat transfers or many concurrent proxies |

- Docker compose for actualbudget
- Currently tested and working

> docker compose sets the user as "1000:1000"

> so make sure to `chown -R 1000:1000 data/`

&nbsp;

**466f724a616e6574**
