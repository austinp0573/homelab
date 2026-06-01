# playbooks

Focused playbooks live in subdirectories:

- `proxmox/alpine_vm.yml`: post-cloud-init Alpine VM configuration
- `network/wireguard_server.yml`: Alpine WireGuard server configuration
- `system/bootstrap.yml`: first-run Debian-family bootstrap
- `system/base.yml`: steady-state Debian-family base configuration

Legacy playbooks remain at this level during the reorganization:

- `bootstrap.yml`: older Debian bootstrap entry point targeting `all`
- `base.yaml`: older base entry point pinned to `sbc-01`
