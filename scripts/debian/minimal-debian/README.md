# minimal-debian

Scripts for a small Debian 13 server. They are meant for a fresh cloud VM or
Proxmox VM after the first successful boot.

The default approach is conservative. It disables services and removes obvious
desktop packages, but does not replace a working provider network setup or run
a broad autoremove.

## setup

```
cp .env.example .env
chmod 600 .env
# edit .env
sudo ./setup.sh
```

Open a second SSH session before rebooting. Check the selected SSH service and
the network before closing the first session.

```
ip -br a
systemctl is-active ssh
systemctl is-active dropbear
```

## profiles

Set `PROFILE` in `.env`.

- `cloud-openssh` is the default and safest starting point.
- `cloud-dropbear` uses Dropbear instead of OpenSSH.
- `proxmox-openssh` keeps the QEMU guest agent.
- `proxmox-dropbear` keeps the QEMU guest agent and uses Dropbear.

Profiles set defaults first. Values in `.env` override them. Each script still
loads `.env`, so it can be run by itself.

Cloud-init is kept by default. Set `PURGE_CLOUD_INIT=y` only after confirming
that the image network configuration will still work without it. Set
`MANAGE_NETWORK=y` only when intentionally moving a host to the generated
systemd-networkd DHCP configuration.

## access

`ADMIN_USER` is required. Set either `ADMIN_PASSWORD` or admin SSH keys.

Use `ADMIN_SSH_KEYS`, or set `SAME_SSH_KEYS=y` to copy `ROOT_SSH_KEYS` to the
admin user. The setup runner installs keys before switching SSH daemons.

`optional/20-disable-root.sh` requires admin SSH keys. Run it only after
testing an admin key login.

## base behavior

- journald is persistent and capped at 50M by default
- unattended security updates are enabled by default
- zram is enabled by default
- nftables starts with an accept policy
- provider networking and DNS are left alone by the supplied profiles
- `core/94-purge-cruft.sh` removes only listed packages and never autoremoves

Set `AUTO_SECURITY_UPDATES=n` if another system manages package updates.

## optional scripts

`OPTIONAL_RUN` accepts space-separated script names.

```
OPTIONAL_RUN="30-ssh-harden.sh 90-nftables-harden.sh"
OPTIONAL_PROMPT=n
```

Run `30-ssh-harden.sh` only after key login works. When using
`90-nftables-harden.sh`, add all public service ports to
`NFT_EXTRA_TCP_PORTS` or `NFT_EXTRA_UDP_PORTS`.

For Tailscale, set `NFT_ALLOW_TAILSCALE=y`. Set
`NFT_TAILSCALE_FORWARD=y` only for subnet routing or an exit node.

HAProxy needs TCP ports 80 and 443. Headscale is bound to localhost by default;
put it behind a proxy if it must be public.

The Nerdctl and Headscale scripts require release SHA256 values in `.env`.
They stop rather than install an unchecked download.

## files

- `core/` is the base setup, run in numeric order
- `optional/` is for extra roles and hardening
- `profiles/` contains cloud and Proxmox defaults
- `lib/common.sh` contains shared helpers
- `pack.sh` creates `send.tar` with the scripts and `.env.example`

## individual scripts

Scripts can be run on their own after `.env` exists.

```
sudo bash core/90-zram-swap.sh
sudo bash core/75-unattended-upgrades.sh
sudo bash optional/90-nftables-harden.sh
```


&nbsp;

**466f724a616e6574**
