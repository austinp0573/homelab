# tinyauth

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### tinyauth

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~5-15 MB | sqlite under ./data, usually tiny | idle |
| expected | 1-3% | ~10-30 MB | MB-scale db | login redirects / session checks |
| high | 0.1-0.3 core | ~64-128 MB | still small | login storms or misbehaving clients |

### gate

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~5-15 MB | nginx alpine tiny | idle |
| expected | 1-5% | ~10-40 MB | logs if enabled | auth-gated request volume |
| high | 0.2-0.5 core | ~64-128 MB | log growth under abuse | scraping / many concurrent hits |

deploy path on host: `/opt/tinyauth/`

password + TOTP gate in front of a few browser UIs. not a full SSO product.

meant for the edge VPS next to haproxy. login UI on `auth.private.example.com`. protected apps (gatus first, later openbao UI / TrueNAS) go through a small nginx `gate` that calls Tinyauth, then proxies to the real backend.

ntfy stays on its own auth (tokens). do not put this in front of machine APIs.

## deploy

1. copy this directory to `/opt/tinyauth/`
2. create the shared network: `nerdctl network create edge-apps`
3. connect the protected app as described in `notes/deploy-upstreams.md`
4. `cp .env.example .env` and edit domains / ports
5. `cp config/users.example config/users` then `./scripts/create-user.sh` (repeat for each person)
6. optional TOTP: `./scripts/enable-totp.sh` (rewrites the user line with a totp secret)
7. `./scripts/up.sh`
8. wire haproxy - `haproxy/backends.example.cfg`
9. cut over gatus - `notes/gatus.md` (drop gatus basic auth once the gate works)
10. `./scripts/smoke.sh`

## layout

```text
/opt/tinyauth/
  .env
  compose.yml
  config/users          # username:bcrypt[:totp]  (gitignored)
  data/                 # sqlite / session material
  gate/nginx.conf       # forward-auth + proxy to backends
```

cookie is set on the parent of `TINYAUTH_APPURL` (e.g. `https://auth.private.example.com` -> `.private.example.com`). use a dedicated parent for the login host and gated apps only.

## ops

```sh
./scripts/up.sh
nerdctl compose logs -f
./scripts/down.sh
```

## related

- gatus: `services/gatus/`
- edge haproxy: `services/edge/`
- ntfy: keep separate (`services/ntfy/homelab-edge/`)
- upstream deployment: `notes/deploy-upstreams.md`
- config notes: `config-explanations.md`


&nbsp;

**466f724a616e6574**
