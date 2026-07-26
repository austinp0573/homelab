# tailscale sidecar compose

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### tailscale

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~30-60 MB | state under /var/lib/tailscale, small | wireguard keepalives |
| expected | 1-5% | ~50-100 MB | state + logs, usually tens of MB | normal tailnet app traffic |
| high | 0.2-1 core | ~128-256 MB+ under big transfers | grows slowly with logs | large file copies / backups over the tailnet |

### app

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | depends on the app you attach | depends on the app | depends on the app | tailnet-only if that is how you publish it |
| expected | see upstream app | see upstream app | see upstream app | normal app traffic over tailscale |
| high | see upstream app | see upstream app | see upstream app | plus wireguard encapsulation cost on the sidecar |

app is the workload sitting behind the tailscale sidecar.

deploy path on hosts: `/opt/tailscale-sidecar/`

rename that directory for whatever service this sits next to. same files either way.

## what this is

tailscale client container sharing its network namespace with an app container. the app is reachable on the tailnet (headscale or Tailscale SaaS). sample app is plain nginx so the wiring is obvious - replace it.

## deploy

1. copy this directory to the host
2. `cp .env.example .env` and edit
3. `cp secrets/authkey.txt.example secrets/authkey.txt` and put a real key in it
4. `./scripts/up.sh`

auth key: file wins over `TS_AUTHKEY` in `.env`. reusable tagged preauth keys are what I use for sidecars so recreating the container is not painful.

headscale:

```sh
headscale preauthkeys create --user <user> --reusable --tags tag:container
```

set `HEADSCALE_URL` to the public headscale url. leave it empty for Tailscale SaaS. `scripts/up.sh` turns that into `--login-server=...`.

## networking

default is kernel TUN (`TS_USERSPACE=false`) with `privileged: true`. set `TS_USERSPACE=true` if you want userspace instead.

sample nginx is published on the host at `HOST_PORT` (8080 by default) because its ports live on the shared netns with the tailscale service. for tailnet-only, delete the `ports:` block under `tailscale` in `compose.yml`.

## state

named volume `ts-state` -> `/var/lib/tailscale`. keeps node identity across restarts. `TS_AUTH_ONCE=true` so it does not force login every start.

## ops

```sh
./scripts/up.sh
nerdctl compose logs -f tailscale
nerdctl compose exec tailscale tailscale status
nerdctl compose down
```

## env notes

most `TS_*` knobs from the official container image are listed in `.env.example`. leave them commented to keep image defaults.

see `config-explanations.md` for the full setting notes.

helpers that are not native container vars, folded into `TS_EXTRA_ARGS` by `up.sh`:

- `HEADSCALE_URL`
- `TS_ADVERTISE_TAGS`
- `TS_ADVERTISE_EXIT_NODE`

anything else goes in `TS_EXTRA_ARGS` or `TS_TAILSCALED_EXTRA_ARGS` directly.


&nbsp;

**466f724a616e6574**
