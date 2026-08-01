# caddy compose

containerized caddy reverse proxy. stock `caddy:alpine` image.

the old alpine/openrc notes stay in `services/caddy/`. this tree is the compose path.

## layout

```text
compose/
  template/     # copy this to a host and run it
  examples/     # full stacks + Caddyfile scraps for common cases
```

deploy path I use: `/opt/caddy/`

## start from the template

1. copy `template/` to the host
2. `cp .env.example .env` and edit
3. edit `Caddyfile` (placeholders for hostnames / backends)
4. `./scripts/up.sh`

scripts prefer `nerdctl compose`, fall back to `docker compose`.

## plugins / custom builds

stock `caddy:alpine` only ships the standard modules. anything else (cloudflare dns, etc.) needs a rebuild.

caddy distributes a tool called `xcaddy` that compiles a binary with extra modules linked in. the official docker image is just that binary plus a thin entrypoint. so a custom image is:

1. start from the caddy builder image (or a go image with xcaddy installed)
2. run `xcaddy build` with `--with github.com/caddy-dns/cloudflare` (or whatever module)
3. copy the resulting binary into a runtime image (alpine is fine)

rough Dockerfile shape:

```dockerfile
FROM caddy:builder AS builder
RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
```

point `CADDY_IMAGE` in `.env` at the image you built/pushed. the Caddyfile and compose file do not change.

on a bare metal install (not this compose tree), `caddy add-package ...` does a similar swap in place. containers do not keep that change across recreates, so bake it into the image instead.

DNS-01 example: `examples/dns-01/`. that Caddyfile will not validate on stock alpine until the dns module is in the binary.

HTTP-01 works on stock alpine with no rebuild. that is what the template assumes.

## examples

see `examples/README.md`. some are full mini compose stacks (edge, sidecar). the rest are Caddyfile scraps you paste into the template.


&nbsp;

**466f724a616e6574**
