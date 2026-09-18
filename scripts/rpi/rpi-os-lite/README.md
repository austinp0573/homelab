# rpi-os-lite

Scripts for a minimal, hardened Raspberry Pi OS Lite setup (ARM64 / ARMhf based on Debian 12 Bookworm or Debian 13 Trixie).

These scripts adapt the `minimal-debian` suite specifically for bare-metal Raspberry Pi hardware, explicitly omitting VM-specific tools and avoiding changes that could disrupt Wi-Fi, Bluetooth, or mDNS (`.local`) hostname resolution.

## Setup

```bash
cp .env.example .env
chmod 600 .env
# Edit .env to set ADMIN_USER and SSH keys / password
sudo ./setup.sh
```

Open a second SSH session before rebooting to verify access.

## Profiles

Set `PROFILE` in `.env`:
- `rpi-openssh` (default): Uses standard OpenSSH server and keeps Raspberry Pi networking/wireless untouched.
- `rpi-dropbear`: Uses Dropbear instead of OpenSSH for low memory footprint.

## Safety & Exclusions vs minimal-debian

To prevent breaking Raspberry Pi OS Lite hardware and networking:
- **Cloud-init & Networkd**: Purging cloud-init and taking over network management via systemd-networkd is excluded. NetworkManager / dhcpcd / wpa_supplicant are left alone.
- **Wireless & Bluetooth**: `bluetooth`, `bluez`, and `network-manager` purges are removed.
- **Avahi / mDNS**: `avahi-daemon` is retained so `.local` hostname resolution continues working.
- **QEMU Agent**: Excluded (not a QEMU VM).
- **DNS**: `MANAGE_DNS=n` by default to preserve DHCP/NetworkManager provided DNS servers.

## Access Requirements

`ADMIN_USER` is required. Set either `ADMIN_PASSWORD` or admin SSH keys (`ADMIN_SSH_KEYS` or `SAME_SSH_KEYS=y`).

## Individual Script Execution

Individual scripts can be executed standalone after `.env` is created:

```bash
sudo bash core/90-zram-swap.sh
sudo bash core/75-unattended-upgrades.sh
sudo bash optional/90-nftables-harden.sh
```
