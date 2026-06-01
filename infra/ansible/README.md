# homelab ansible

This directory is the working Ansible repo for homelab and small VPS systems.

The repo is organized around small playbooks and reusable roles. Environment-specific inventories live under `inventories/`, while shared behavior lives under `roles/`.

## layout

```text
inventories/
  homelab/
    hosts.example.yml
    hosts.yml
cloud-init/
  proxmox/
    alpine/
playbooks/
  network/
    wireguard_server.yml
  proxmox/
    alpine_vm.yml
roles/
  alpine_baseline/
  alpine_low_resource/
  proxmox_guest/
  wireguard_server/
```

`hosts.yml` is for local inventory data and should stay out of git. Start from the example inventory and keep hostnames, addresses, keys, and private values local or in an encrypted vault.

## alpine proxmox vm

The first focused playbook is for an Alpine Linux VM on Proxmox after cloud-init has completed the initial bootstrap.

```sh
ansible-playbook playbooks/proxmox/alpine_vm.yml
```

Cloud-init should get the host reachable and install enough base tooling for Ansible, including Python. After that, this playbook owns the desired state: users, doas, shell profile, packages, Dropbear, Proxmox guest agent, low-resource tuning, swap/zram, and cleanup.

NoCloud examples live in `cloud-init/proxmox/alpine/`. They are intentionally minimal first-boot bootstrap snippets, not a replacement for Ansible.

Alpine inventory entries should use `ansible_become_method: doas`. The default doas rules keep the `ansible` management user passwordless while allowing wheel users to use persistent doas.

Alpine hosts use Dropbear as the managed SSH server. The baseline role still installs the OpenSSH SCP client package so legacy SCP transfers work against Dropbear, and `ansible.cfg` forces legacy SCP mode with `scp_extra_args = -O`.

The low-resource role keeps Python, apk, certificates, Dropbear, the OpenSSH client/SCP bits, networking, and qemu guest agent by default. More aggressive behavior is controlled by variables.

## wireguard server

The WireGuard playbook provisions Alpine Linux WireGuard servers with nftables peer access controls.

```sh
ansible-playbook playbooks/network/wireguard_server.yml
```

Use `inventories/homelab/group_vars/wireguard_servers.example.yml` as the public-safe starting point. Keep real server private keys, peer keys, endpoints, and allowlists in ignored inventory or encrypted vars.

The role owns the configured nftables ruleset path, defaulting to `/etc/nftables.nft`, so review existing firewall usage before applying it to a host with other nftables-managed services.
