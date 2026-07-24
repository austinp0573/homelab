# gatus cutover

goal: browser hits `https://status.private.example.com` -> haproxy -> tinyauth gate -> gatus.
login happens on `https://auth.private.example.com`.

## before

gatus has its own HTTP basic auth (`services/gatus/config/10-security.yaml`).

## after tinyauth works

1. confirm you can log in at auth.private.example.com and reach status.private.example.com through the gate.
2. remove or comment the `security:` block in gatus `config/10-security.yaml`.
3. restart gatus.
4. `./scripts/smoke.sh` in both trees.

leaving both on means password (gatus) then password+TOTP (tinyauth) - useless.

## health checks

gatus `/health` is unauthenticated at the app. if the gate wraps all paths on status.private.example.com, external monitors that hit the public URL will get a login redirect.

options:

- point checks at `http://127.0.0.1:8080/health` on the VPS (local)
- or add a gate location `= /health` without auth_request (only if you are ok exposing health publicly)

local check is the simple choice.

see also: comment or remove `security:` in `services/gatus/config/10-security.yaml` after cutover.
