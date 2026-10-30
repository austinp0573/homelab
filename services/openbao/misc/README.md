# openbao

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### openbao

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 1-3% | ~50-100 MB | image + empty raft dir, hundreds of MB | idle listener |
| expected | 5-15% | ~150-400 MB | raft data usually hundreds of MB to a few GB | API calls, unseal, occasional snapshot |
| high | 0.5-2 cores | ~512 MB-1.5 GB | raft + snapshots can be multi-GB | heavy secret churn, large list ops, snapshot/restore |

Reported RSS can look higher because of page cache on raft files.

### cloudflared

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~30-50 MB | image ~50-80 MB, almost no state | keepalive / control plane only |
| expected | 2-10% | ~64-128 MB | config / credentials only | matches proxied app traffic |
| high | 0.2-0.5+ core | ~256-512 MB (can climb more if buffering) | still tiny on disk | sustained high throughput or many concurrent streams |

QUIC tends to cost more CPU than http2 for the same traffic.


&nbsp;

**466f724a616e6574**
