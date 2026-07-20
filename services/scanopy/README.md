# scanopy

interesting network exploration/mapping tool

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### server

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-3% | ~50-100 MB | app + static assets | idle API/UI |
| expected | 5-15% | ~100-250 MB | grows with scan results in postgres | UI + agent reporting |
| high | 0.5-1 core | ~400-800 MB | large result history | big scans correlating lots of hosts |

### daemon

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-3% | ~40-80 MB | small config volume | local scans |
| expected | 10-40% during scans | ~80-200 MB | tiny | host/network scanning bursts |
| high | 1+ core while scanning wide ranges | ~300-500 MB | tiny | aggressive network discovery |

Daemon runs host/privileged and can generate meaningful network chatter during scans.

### postgres

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-3% | ~32-64 MB (tiny shared_buffers) | empty cluster ~40 MB | local only |
| expected | 5-20% | ~100-300 MB | grows with data + WAL | app query traffic |
| high | 1+ core | ~512 MB-2 GB depending on shared_buffers / work_mem | multi-GB if datasets grow | bulk import, vacuum, analytics queries |


&nbsp;

**466f724a616e6574**
