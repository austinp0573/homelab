# integrations

public base: `https://ntfy.example.com` (placeholder).

create a publisher per system:

```sh
./scripts/create-publisher.sh gatus
./scripts/create-publisher.sh restic
./scripts/create-publisher.sh borg
./scripts/create-publisher.sh lab
```

script prints a token. store it on the publisher host (env file / secret), not in git. optional: paste a reminder into `secrets/<topic>-token.txt` on the ntfy host (gitignored).

to revoke a publisher's old token, replace the publisher:

```sh
./scripts/replace-publisher.sh gatus
```

---

## gatus

copy `services/gatus/config/20-alerting.yaml.example` to `20-alerting.yaml` first. the real file is ignored and may contain the token:

```yaml
alerting:
  ntfy:
    url: "https://ntfy.example.com"
    topic: "gatus"
    token: "tk_..."
    priority: 3
```

restart/reload gatus after edit.

---

## restic

compose/scripts already have `NTFY_*` knobs in places. pattern:

```sh
curl -sS -H "Authorization: Bearer tk_..." \
  -H "Title: restic ok" \
  -d "backup finished on $(hostname)" \
  https://ntfy.example.com/restic
```

or on failure hit the same topic with a higher priority header (`Priority: high`).

---

## borg / borgmatic

same as restic. topic `borg`. borgmatic has a native ntfy hook in some configs (`services/borg/` examples mention ntfy server/topic/token).

---

## other publishers worth adding later

| topic | source |
|-------|--------|
| watchtower / diun | container update notifier |
| ups | nut / lab-ups scripts on power events |
| healthchecks | if you self-host healthchecks and want a bridge; or skip and let jobs post here directly |
| openbao | raft/snapshot script success/fail |
| vaultwarden | litestream / backup wrappers |
| edge | haproxy/cert renew failures (cron) |

keep one topic per system so phone filters stay simple.

---

## phone app

1. add server `https://ntfy.example.com`
2. log in as admin (or a read-only user you create later)
3. subscribe to `gatus`, `restic`, ...

---

## publish smoke

```sh
curl -sS -H "Authorization: Bearer tk_..." \
  -d "test from integrations notes" \
  https://ntfy.example.com/gatus
```
