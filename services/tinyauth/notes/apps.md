# other apps (placeholders)

same pattern as gatus: public hostname -> haproxy -> tinyauth gate -> upstream.

edit `gate/nginx.conf` server_name + proxy_pass, add haproxy ACL, reload both.

## openbao UI

placeholder host: `bao-ui.private.example.com`

upstream in the example points at `host.docker.internal:8200`. that only makes sense if the UI is on the same VPS. for lifeboat/openbao over headscale, change proxy_pass to the tailnet IP (or run the gate on a host that can reach it and point haproxy there).

openbao still has its own token/userpass. tinyauth is only the browser door.

## TrueNAS

placeholder host: `truenas.private.example.com`

TrueNAS UI is usually HTTPS on the NAS. options later:

- VPN/tailnet only (no public gate) - often enough
- haproxy -> gate -> https://nas-tailnet-ip (nginx `proxy_ssl` bits)
- expose a dedicated hostname only when you really want it from the internet

do not ship TrueNAS admin to the world without tinyauth (or better, without tailnet).

## do not gate

| thing | why |
|-------|-----|
| ntfy publish API | bearer tokens; TOTP breaks machines |
| headscale | its own auth |
| vaultwarden | app has 2FA; double gate is painful |
| public marketing/static | N/A |
