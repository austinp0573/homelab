# caddy

```sh
apk update && apk add caddy libcap-setcap
mkdir -p /var/log/caddy /etc/caddy
chown -R caddy:caddy /var/log/caddy /etc/caddy

# create /etc/caddy/Caddyfile
# see services/caddy/
```

By default, non-root processes cannot bind to privileged ports below 1024. Grant Caddy security capability exceptions to bind to ports 80 and 443 safely as a low-privilege user:

```bash
sudo setcap 'cap_net_bind_service=+ep' /usr/sbin/caddy
sudo rc-update add caddy default
sudo rc-service caddy start
```

> Running `setcap` is mandatory on hardened Linux kernels to allow the non-root `caddy` user to listen for raw port 80/443 traffic. Skipping this step will cause the OpenRC init service to crash silently on boot with a "permission denied" error in the syslog.

## Getting valid SSL certs

The vanilla Caddy package installed via `apk add caddy` does not contain DNS provider modules out of the box. A DNS provider plugin to must be added to allow Caddy to dynamically write a temporary TXT record to the DNS zone to prove domain ownership.

#### Compile the Custom DNS Module into the Native Binary

Execute Caddy's native binary extension utility using administrator privileges on the dedicated proxy VM:

```bash
doas caddy add-package github.com/caddy-dns/cloudflare
```

Verify that the underlying compilation layer successfully registered the cryptographic challenge hooks:

```bash
caddy list-modules | grep dns
```

> The `add-package` command contacts the upstream Caddy compilation engine, downloads a binary matching your architecture with the `cloudflare` plugin injected, and safely hot-swaps your local `/usr/sbin/caddy` file. If the system throws an error regarding directory locks, temporarily halt the daemon using `doas rc-service caddy stop` before executing the addition.

#### Get the Cloudflare API Token

1. Go to [cloudflare dashboard](https://dash.cloudflare.com)
2. Login with yubikey
3. `manage account` -> `account api tokens`
4. `Create Token`
5. Give the token a descriptive name so you know why it exists a long time from now.
6. ~~`Entire Account`~~ -> Select `Specific Domains` instead.

**Only grant the permission it NEEDS.**

| Permission Category | Specific Permission | Access Level | Reason |
| --- | --- | --- | --- |
| **Zone** | **Zone** | **Read** | Allows Caddy to look up the domain's unique 32-character **Zone ID** inside Cloudflare using the string name `example.example.org`. |
| **Zone** | **DNS** | **Edit** | Allows Caddy to dynamically create, modify, and delete the temporary `_acme-challenge.example.example.org` **TXT record** required by Let's Encrypt. |

7. Create the token.
8. You will only get the token once, store it in an encrypted format.

#### Securely Inject the DNS API Token

Map the API access token directly to the system environment.

Open the OpenRC environment override file:

```bash
doas vi /etc/conf.d/caddy

```

Append the token:

```sh
# File path: /etc/conf.d/caddy
export CLOUDFLARE_API_TOKEN="CLOUDFLARE_API_TOKEN"
```

Lock down permissions:

```bash
doas chmod 600 /etc/conf.d/caddy
```

> This file is parsed automatically by the Alpine OpenRC init subsystem before firing up the daemon.


Use the new token in the **caddy** configuration file (`/etc/caddy/Caddyfile`)

```text
# File path: /etc/caddy/Caddyfile

{
    # Global configurations
    email email@example.com
    admin local:port
}

# Wildcard Block capturing all subdomains under *.example.com
*.example.com {
    # Force DNS-01 verification via the compiled Cloudflare module
    tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        protocols tls1.3
    }

    # Security Hardening Headers
    header {
        X-Frame-Options "DENY"
        X-Content-Type-Options "nosniff"
        Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    # Layer 7 Multiplexing Matrix
    @example host example.example.com
    handle @example {
        reverse_proxy 192.168.1.5:4933
    }

    # Catch-all handler to drop unmapped subdomain queries gracefully
    handle {
        abort
    }
}

```

> This replaces your specific single-domain blocks with an umbrella tracking layout. The syntax `{env.CLOUDFLARE_API_TOKEN}` tells Caddy to extract the string values defined inside `/etc/conf.d/caddy` at runtime. The `@budget` host matching rule acts as an internal traffic cop, routing requests that explicitly match the domain down to the backend VM, while dropping unrecognized names immediately.

execute a complete service restart:

```bash
doas rc-service caddy restart

```