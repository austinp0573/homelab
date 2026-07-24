# config explanations

## `.env`

`COMPOSE_PROJECT_NAME`

Compose project name. Default: `tinyauth`.

`RESTART_POLICY`

Container restart policy. Default: `unless-stopped`.

`TINYAUTH_CONTAINER_NAME` and `GATE_CONTAINER_NAME`

Container names. Keep them unique on the edge VPS.

`TINYAUTH_IMAGE`

Tinyauth image. Default: `ghcr.io/tinyauthapp/tinyauth:v5.0.7`.

The patch version is pinned so proxy behavior does not change unexpectedly during a recreate.

`GATE_IMAGE`

Nginx image for the gate. Default: `nginx:1.27-alpine`.

`TINYAUTH_APPURL`

Public login URL. Default: `https://auth.private.example.com`.

Tinyauth sets its cookie on the parent domain. Keep the login host and protected app hosts below a dedicated parent such as `.private.example.com`.

`HOST_BIND`

Host address for the Tinyauth and gate ports. Default: `127.0.0.1`.

Keep localhost when HAProxy runs on the same edge VPS.

`TINYAUTH_HOST_PORT`

Host port for the login UI. Default: `3000`.

`GATE_HOST_PORT`

Host port for the nginx gate. Default: `8088`.

`DATA_DIR`

Host directory for the Tinyauth SQLite database and session material. Default: `./data`.

Back it up if existing sessions matter. Do not commit it.

`TINYAUTH_AUTH_SECURECOOKIE`

Only sends the auth cookie over HTTPS. Default: `true`.

Keep it enabled when HAProxy terminates HTTPS.

`TINYAUTH_AUTH_TRUSTEDPROXIES`

Proxy networks allowed to supply forwarded headers. The default includes loopback and common private container networks so Tinyauth trusts the nginx gate.

Do not expose Tinyauth directly to an untrusted private network with this broad setting.

`TINYAUTH_AUTH_SESSIONEXPIRY`

Session lifetime in seconds. Default: `86400`, or one day.

Lower it for a shorter login window. Raise it only if the convenience is worth the longer session.

`TINYAUTH_AUTH_USERS`

Filled by `scripts/up.sh` from `config/users`. Do not put users here manually.

The value contains bcrypt hashes and TOTP seeds while the container runs. Local container inspection access is authentication-sensitive access.

`TINYAUTH_ANALYTICS_ENABLED`

Enables the upstream analytics and version ping. Default: `false`.

`TINYAUTH_LOG_LEVEL`

Tinyauth log level. Default: `info`. Use `debug` only while troubleshooting.

## `config/users`

One user per line:

```text
username:bcrypt_hash
username:bcrypt_hash:totp_secret
```

Create lines with:

```sh
./scripts/create-user.sh
./scripts/enable-totp.sh
```

Those wrap the upstream CLI. Restart Tinyauth after editing the file so it reloads the user list.

`config/users` is ignored. Keep its permissions private because TOTP seeds can be used to generate login codes.

## compose services

`tinyauth` serves the login UI and `/api/auth/nginx`.

`gate` runs nginx `auth_request` checks for protected hosts, then proxies to the real app.

The gate joins the default Tinyauth network and the external `edge-apps` network. `edge-apps` is how it reaches local protected containers such as Gatus.

Create the external network before starting this stack:

```sh
nerdctl network create edge-apps
```

See `notes/deploy-upstreams.md` for the other side of that network.

## `gate/nginx.conf`

Server blocks currently exist for:

- `status.private.example.com` to Gatus
- `bao-ui.private.example.com` as an OpenBao template
- `truenas.private.example.com` as a TrueNAS template

HAProxy sends `auth.private.example.com` directly to Tinyauth. It sends protected hosts to the gate.

`/health` only proves nginx is running. `/auth-health` reaches Tinyauth's nginx auth endpoint and returns `401` without a cookie. HAProxy uses the second endpoint for its backend check.

## cookie scope

One Tinyauth instance shares a login cookie across hosts under the parent of `TINYAUTH_APPURL`.

Use a dedicated parent only for apps that share a trust boundary. Use another Tinyauth instance when an app should not receive the same cookie.
