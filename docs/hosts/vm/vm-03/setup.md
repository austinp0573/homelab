# vm-03 setup

run `setup-alpine`

- set static IP (DMZ VLAN)

run alpine scripts (remove 10-apk-update.sh & 30-minimal-dropbear.sh)

```sh
apk update && apk add qemu-guest-agent
rc-update add qemu-guest-agent default
rc-service qemu-guest-agent start
```

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

> **Relationship & Gotchas:** Running `setcap` is mandatory on hardened Linux kernels to allow the non-root `caddy` user to listen for raw port 80/443 traffic. Skipping this step will cause the OpenRC init service to crash silently on boot with a "permission denied" error in the syslog.

