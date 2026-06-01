# alpine_low_resource

Applies conservative low-resource tuning for Alpine VMs.

## scope

- writes a configurable kernel module blacklist
- optionally manages mkinitfs and bootloader kernel options
- removes selected nonessential packages
- disables selected services
- configures sysctl tuning, zram, optional swapfile, syslog buffering, and disk read-ahead

## conservative defaults

The role keeps the management path intact by default:

- Python stays installed
- apk and certificates stay installed
- Dropbear stays installed
- OpenSSH client/SCP packages stay installed
- networking stays intact
- qemu guest agent stays installed
- bootloader edits are disabled by default
- IPv6 is not disabled by default
- OpenSSH server removal is opt-in

## risky knobs

- `alpine_low_resource_manage_bootloader`: enables mkinitfs and extlinux edits.
- `alpine_low_resource_disable_ipv6`: writes IPv6-disable tuning and, when bootloader management is enabled, adds the kernel disable option.
- `alpine_low_resource_remove_openssh_server`: removes OpenSSH server packages after Dropbear is configured.
- `alpine_low_resource_remove_packages`: should stay focused on packages that are not part of management, networking, certificates, Python, or Proxmox guest support.
