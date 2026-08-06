# cloudflared vaultwarden

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### vaultwarden-service

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% of 1 core | ~30-50 MB | image ~180 MB + tiny sqlite | nearly idle |
| expected | 1-5% | ~80-120 MB | sqlite tens of MB + attachments | short HTTPS bursts on client sync |
| high | briefly up toward 1 core | ~200-300 MB | grows with attachments / history | many clients syncing at once, or a big import |

### cloudflared

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~30-50 MB | image ~50-80 MB, almost no state | keepalive / control plane only |
| expected | 2-10% | ~64-128 MB | config / credentials only | matches proxied app traffic |
| high | 0.2-0.5+ core | ~256-512 MB (can climb more if buffering) | still tiny on disk | sustained high throughput or many concurrent streams |

QUIC tends to cost more CPU than http2 for the same traffic.


&nbsp;

**466f724a616e6574**
