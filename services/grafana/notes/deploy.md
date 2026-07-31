# deploy notes

host-agnostic. same files on a home box or an edge vps.

## copy

repo layout keeps prometheus and loki under `services/grafana/` so they live with the ui docs. on the host, treat them as three trees:

```text
/opt/grafana/      <- services/grafana/          (not the whole repo tree)
/opt/prometheus/   <- services/grafana/prometheus/
/opt/loki/         <- services/grafana/loki/
```

do not copy `prometheus/` and `loki/` into `/opt/grafana/` unless you want that layout; the scripts do not require nesting.

## order

1. prometheus
2. loki
3. grafana

smoke each as you go.

## firewall

defaults bind 127.0.0.1. if something else on the host needs to scrape or push, either open a specific bind or proxy through something that already terminates tls.

## edge vs home

home: more ram/disk, better place for longer retention and more scrapes.

edge: works for a small set of targets. watch ram. keep retention short. avoid shipping every container log until you know the volume.

## backups

worth including in restic/borg:

- `/opt/grafana/data`
- `/opt/prometheus/data` (optional; metrics are often rebuilt)
- `/opt/loki/data` (optional; logs are often treated as expendable)

dashboards you care about should also live as json under provisioning (or export them).
