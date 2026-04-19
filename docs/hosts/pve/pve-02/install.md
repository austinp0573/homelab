# pve-02 — Proxmox Install

## Proxmox Install

| Parameter | Value | Thoughts |
| --- | --- | --- |
| **Filesystem** | `ext4` | Standard, rock-solid stability for the OS root partition. |
| **hdsize** | `931` | (Approx) Use the full disk capacity (1TB decimal $\approx$ 931-953 GiB). |
| **swapsize** | `16` | Matches standard RAM for an Optiplex; provides a safety net for OOM events. |
| **maxroot** | `80` | Allocates 60GB for `/`. Sufficient for logs, OS, and some ISO storage. |
| **maxvz** | `0` | **Mandatory.** Prevents a large `/var/lib/pve/local-vzdump`. Forces LVM-Thin. |
| **minfree** | `93` | Reserves ~10% of the 1TB. Critical for LVM snapshot metadata overhead. |

* **Relationship:** The `data` pool is a "thin" container. If you allocate 500GB to a VM but only install 10GB of software, only 10GB is subtracted from the pool's physical capacity.
* **Gotcha:** If you ignore `maxvz=0`, the installer creates a standard directory on the root partition for backups. On a 1TB drive, this often results in a massive OS partition and a tiny, useless Thin Pool.

## Network Configuration

* **Management Interface:** Onboard Intel 1Gbps NIC
* **Hostname:** `${PVE02_HOSTNAME}`
* **IP Address:** `${PVE02_IP}` (management network)
* **Gateway:** `${PVE_GATEWAY_OR_DNS}` (gateway)
* **DNS:** `${PVE_GATEWAY_OR_DNS}` (gateway)

## Post Install

**Enable Added Intel i226v NIC**

- Select pve-02
- Network Tab
- NIC0 -> Edit
- Check `AutoStart`
- `Apply Configuration`

**Proxmox VE Helper Script Post Install**

After install go to the [pve helper scripts post install page](https://community-scripts.github.io/ProxmoxVE/scripts?id=post-pve-install&category=Proxmox+%26+Virtualization)

where you will find the following command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
```

run it in the PVE shell.

- don't want pve-enterprise or ceph-enterprise
- don't enable test
- don't update/upgrade -> run `apt update && apt full-upgrade -y` after the script is done
- reboot

**Enable VLAN Support**

- `apt install vim-nox`
- `vim /etc/network/interfaces`
- add `bridge-vlan-aware yes` block at the end of the `vmbr0` block
- to apply changes without a reboot run: `ifreload -a`

**Add Admin User**

- `adduser <user-name>`
- `pveum user add <user-name>@pam --comment "<optionally-add-comment>"`
    - Tell Proxmox to recognize this existing Linux user within its management interface.
    - The `@pam` suffix is critical. It tells Proxmox to defer authentication to the Linux system rather than its internal database.
- `pveum acl modify / -user <user_name>@pam -role Administrator`
    - By default, a new user has zero permissions in the Proxmox GUI
    - Path: `/` (The entire cluster).
    - Role: `Administrator` (Full GUI access).
- `usermod -aG sudo <user-name>`
    - Add the user to the `sudo` group.

**Add SSH Key**

- add ssh key (`ssh-copy-id -i ~/.ssh/<key to use> <pve-user>@<pve-DNS or IP>`
- run `ssh-keygen -R <pve-DNS or IP>` to move to known_hosts.old if this is a reinstall)
- connect via SSH
