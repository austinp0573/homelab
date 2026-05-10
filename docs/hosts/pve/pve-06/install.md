# pve-06 — Proxmox Install

## Proxmox Install

| Parameter | Value | Thoughts |
| --- | --- | --- |
| **Filesystem** | `ext4` | Standard, rock-solid stability for the OS root partition. |
| **hdsize** | `1,863GB` | (Approx) Use the full disk capacity |
| **swapsize** | `8GB` | Matches standard RAM for an Optiplex; provides a safety net for OOM events. |
| **maxroot** | `50GB` | Allocates 60GB for `/`. Sufficient for logs, OS, and some ISO storage. |
| **minfree** | `32GB` | Reserves ~10% of the 1TB. Critical for LVM snapshot metadata overhead. |
| **maxvz** | `0GB` | **Mandatory.** Prevents a large `/var/lib/pve/local-vzdump`. Forces LVM-Thin. |

* **Relationship:** The `data` pool is a "thin" container. If you allocate 500GB to a VM but only install 10GB of software, only 10GB is subtracted from the pool's physical capacity.
* **Gotcha:** If you ignore `maxvz=0`, the installer creates a standard directory on the root partition for backups. On a 1TB drive, this often results in a massive OS partition and a tiny, useless Thin Pool.

## GPU Pass Through

**1. Enable IOMMU in the bootloader**

Edit `/etc/default/grub`, find `GRUB_CMDLINE_LINUX_DEFAULT` and add:

```
intel_iommu=on iommu=pt
```

`iommu=pt` (passthrough mode) is important — it reduces overhead for devices *not* being passed through. Then run `update-grub`.

**2. Verify IOMMU is actually working after reboot**

```bash
dmesg | grep -e DMAR -e IOMMU
```

You want to see DMAR entries and no errors. Also run:

```bash
find /sys/kernel/iommu_groups/ -type l
```

If you get output, IOMMU grouping is active.

**3. Check your IOMMU groups**

This is the X99 gotcha moment. Run:

```bash
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n=${d#*/iommu_groups/*}; n=${n%%/*}
  printf 'IOMMU Group %s ' "$n"
  lspci -nns "${d##*/}"
done
```

You want the R9700 and its audio device in their own group, isolated. If other devices are in the same group, you either pass them all through together or use `pcie_acs_override=downstream,multifunction` added to your grub cmdline. ACS override is a security compromise but on a homelab it doesn't matter.

**4. Load VFIO modules**

Add to `/etc/modules`:

```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

Create `/etc/modules-load.d/vfio.conf`:

/etc/modules-load.d/vfio.conf
```bash
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

Note: `vfio_virqfd` was merged into the vfio core module in kernel 6.2+. Proxmox 8 runs a recent kernel so it's harmless to include but won't do anything.

run: `update-initramfs -u -k all`

**5. Blacklist amdgpu on the host**

You do not want the host loading the amdgpu driver for the R9700 — VFIO needs to claim it first.

Get the PCI IDs:
```bash
lspci -nn | grep AMD
```

You'll see something like `[1002:687f]` — grab both the GPU and its audio function IDs.

Create `/etc/modprobe.d/vfio.conf`:
```
options vfio-pci ids=1002:XXXX,1002:XXXX
softdep amdgpu pre: vfio-pci
```

Then create `/etc/modprobe.d/blacklist-amdgpu.conf`:
```
blacklist amdgpu
blacklist radeon
```

Run `update-initramfs -u -k all` then reboot.

**6. Verify VFIO claimed the GPU**

```bash
lspci -nnk | grep -A3 AMD
```

You want to see `Kernel driver in use: vfio-pci` for the R9700, not `amdgpu`.

---

## VM Configuration in Proxmox

- **Machine type:** q35 (required for PCIe passthrough)
- **BIOS:** OVMF (UEFI, not SeaBIOS)
- **CPU type:** `host` — this exposes the actual CPU flags to the guest, ROCm needs this
- **Add PCI Device:** select the R9700, check **All Functions**, check **ROM-Bar**, check **PCI-Express**
- Do NOT check "Primary GPU" in Proxmox unless you have no other display output — this can cause boot issues

**Gotcha:** with OVMF you need an EFI disk. Proxmox will prompt you to add one when you select OVMF — do it.

**Gotcha:** if the VM boots but the GPU isn't visible inside it, the most common cause is the IOMMU group issue from step 3 above, not a driver problem.

---

Once the VM is booting and you can see the GPU with `lspci` inside the guest, *then* install ROCm. Installing ROCm before confirming passthrough works just adds noise to debugging.

## Network Configuration

* **Management Interface:** Onboard Intel 1Gbps NIC
* **Hostname:** `${PVE06_HOSTNAME}`
* **IP Address:** `${PVE06_IP}`
* **Gateway:** `${PVE06_GATEWAY}`
* **DNS:** `${PVE06_DNS}`

## Post Install

**Enable Added Intel i226v NIC**

- Select pve-06
- Network Tab
- NIC0 -> Edit
- Check `AutoStart`
- `Apply Configuration`

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
