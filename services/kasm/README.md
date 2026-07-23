# kasm

This stack is a single kasmweb desktop image, not the full multi-agent Kasm product.

deploy path on host: `/opt/kasm/`

standalone browser desktop via a kasmweb workspace image. the image already includes kasmvnc + an ubuntu xfce session. this is not the full kasm workspaces product (no broker, no multi-session portal) - just one container you open in a browser.

default image: `kasmweb/desktop:1.19.0` (ubuntu xfce). pin or swap the tag in `.env` when you want something else.

## deploy

1. copy this directory to `/opt/kasm/`
2. `cp .env.example .env`
3. `cp secrets/vnc.env.example secrets/vnc.env` and set `VNC_PW`
4. `./scripts/up.sh`
5. `./scripts/smoke.sh`

open `https://127.0.0.1:6901` (or whatever you set in `.env`). login user is always `kasm_user`. the container serves https with a self-signed cert, so the browser will complain unless you put a real cert on a reverse proxy in front.

```sh
./scripts/up.sh
nerdctl compose logs -f
./scripts/smoke.sh
./scripts/down.sh
```

scripts use `nerdctl compose` if present, otherwise `docker compose`.

## layout

```text
/opt/kasm/
  .env
  compose.yml
  data/                 # bind mounted to Downloads
  secrets/vnc.env
  haproxy/backend.example.cfg
```

## other images

set `KASM_IMAGE` in `.env`. same ports / `VNC_PW` / user for the usual kasmweb app images, for example:

- `kasmweb/chrome:1.19.0`
- `kasmweb/firefox:1.19.0`
- `kasmweb/ubuntu-jammy-desktop:1.19.0`

core images exist too if you want to build your own layer on top. see https://hub.docker.com/u/kasmweb and the workspaces image docs.

## persistence

compose mounts `${DATA_DIR}` (default `./data`) to `/home/kasm-user/Downloads`. that keeps browser downloads and anything you drop there without covering the image's home directory.

if you bind-mount over `/home/kasm-user` instead, an empty host dir hides the image home (desktop config, etc.) and the session can look broken on first boot. only do that if you are intentionally managing a full home tree on the host.

ephemeral is fine too - remove the volume line if you want a clean desktop every restart.

## shm

`SHM_SIZE` defaults to `1gb`. kasm's own examples use `512m`; chrome and similar inside the desktop are happier with more. bump again if you see crashes that mention shared memory.

## tls / reverse proxy

stock image (what this template uses): https on 6901 with a snakeoil cert. keep `HOST_BIND=127.0.0.1` and put haproxy (or whatever) in front.

two workable patterns:

A - terminate tls on the proxy, talk https to the container and ignore the snakeoil upstream. scrap in `haproxy/backend.example.cfg`. websocket-ish traffic needs a long tunnel timeout.

B - make kasmvnc speak plain http (`require_ssl: false` in a mounted `kasmvnc.yaml`), then proxy http like any other local service. more config, nicer if you want one consistent http backend style. see https://www.kasmweb.com/kasmvnc/docs/latest/how_to/reverse_proxy.html

tcp passthrough also works (client sees the container cert). usually worse than A.

## auth

template only sets `VNC_PW` via `secrets/vnc.env` (compose `env_file`). that is kasmvnc basic auth.

optional extra gate: put tinyauth / whatever on the edge proxy in front. do not put a second basic-auth challenge that eats the `Authorization` header kasmvnc needs - if the proxy does basic auth, it has to forward that header or use a different auth mode.

## gpu / extras

left plain on purpose. no privileged, no `/dev/dri`. if you want gpu accel later, that is host-specific (devices, group adds, maybe `hw3d` in kasmvnc config). audio / upload / mic passthrough are mostly kasm platform features and are limited in standalone mode.

## ops notes

desktop images take a bit to come up - smoke waits up to 90s. if the ui never answers, check `nerdctl compose logs`.


&nbsp;

**466f724a616e6574**
