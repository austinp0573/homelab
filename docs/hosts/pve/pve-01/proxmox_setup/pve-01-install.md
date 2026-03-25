# pve-01 

- Dell Optiplex 7060 SFF - i5-8500 - 32GB RAM (2x16GB Dual Channel), 1TB SATA SSD

### BIOS

- Integrated NIC: Enabled
- Secure Boot: Disabled
- Virtualization Support: All Enabled
- AC Recovery: Power-Off
- Wake on LAN: Enabled

### Proxmox Install

| Parameter | Value | Thoughts |
| --- | --- | --- |
| **Filesystem** | `ext4` | Standard for single-drive consumer nodes; lower overhead than XFS. |
| **hdsize** | `931` | Total usable capacity (1000GB decimal $\approx$ 931 GiB). |
| **swapsize** | `16` | 32GB of RAM on the host, smaller could cause OOM issues |
| **maxroot** | `80` | 50GB is the "sweet spot" for Proxmox OS, updates, and small log files. |
| **maxvz** | `0` | **Mandatory.** Prevents the creation of `/var/lib/pve/local-vzdump`, forcing LVM-Thin. |
| **minfree** | `93` | Reserves ~10% of the disk. Essential for LVM metadata and drive health. |

* **Relationship:** The `data` pool is a "thin" container. If you allocate 500GB to a VM but only install 10GB of software, only 10GB is subtracted from the pool's physical capacity.
* **Gotcha:** If you ignore `maxvz=0`, the installer creates a standard directory on the root partition for backups. On a 1TB drive, this often results in a massive OS partition and a tiny, useless Thin Pool.

### Network configuration

3. **Management Interface:** Onboard Intel 1Gbps NIC
* **Hostname:** `pve-01.management.tusko.org`
* **IP Address:** `10.0.10.4/24` (Management VLAN)
* **Gateway:** `10.0.10.1` (pfSense)
* **DNS:** `10.0.10.1` (pfSense)

## Post Install

**Enable VLAN Support**

- `apt install vim-nox`
- `vim /etc/network/interfaces`
- add `bridge-vlan-aware yes` block at the end of the `vmbr0` block
- to apply changes without a reboot run: `ifreload -a`

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