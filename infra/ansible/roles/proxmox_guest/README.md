# proxmox_guest

Installs and enables guest integration packages for Alpine VMs running on Proxmox.

## scope

- installs `qemu-guest-agent` and its OpenRC package
- enables and starts the guest agent service

This role is intentionally small. Proxmox host/API work and VM creation are separate concerns.

This role only configures the guest after cloud-init has made it reachable.
