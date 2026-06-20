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
lspci -nn | grep -i amd
```

```bash
03:00.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 10 XL Upstream Port of PCI Express Switch [1002:1478] (rev 24)
04:00.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 10 XL Downstream Port of PCI Express Switch [1002:1479] (rev 24)
05:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 48 [Radeon AI PRO R9700] [1002:7551] (rev c0)
05:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 48 HDMI/DP Audio Controller [1002:ab40]
```

Create `/etc/modprobe.d/vfio.conf`:
```
options vfio-pci ids=1002:1478,1002:1479,1002:7551,1002:ab40
softdep amdgpu pre: vfio-pci
```

Then create `/etc/modprobe.d/blacklist-amdgpu.conf`:

```bash
blacklist amdgpu
blacklist radeon
```

Run `update-initramfs -u -k all` then reboot.

**6. Verify VFIO claimed the GPU**

```bash
lspci -nnk | grep -A3 AMD
```

You want to see `Kernel driver in use: vfio-pci` for the R9700, not `amdgpu`.

**7. Set CPU to performance**

Run `apt install linux-cpupower` and set the host to max performance: `cpupower frequency-set -g performance`.

---

## Acquire ubuntu server cloud image

- go to cloud-image.ubuntu.com
- select the apropriate image

```bash
curl -o /var/lib/vz/template/iso/<image_name> https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img <or whatever image>
```

## Configure network
- **pve-06**
    - **Network**
        - **i226v** -> `edit`
            - **Autostart:** - **`UNCHECK`**
            - **Comment:** - `m.2 -> i226v adapter - 2.5Gbps`
        - **vmbr0**
            - **VLAN aware:** - `CHECK`
            - **Comment:** - `primary bridge - mgmt`
        - **Create -> Linux Bridge**
            - **Name:** - `vmbr1` (default)
            - **IP*:** - None, this is for VM traffic
            - **Autostart:** - `CHECK`
            - **VLAN aware:** - `CHECK`
            - **Bridge ports:** - `i226v`
            - **Comment:** - `vm bridge attached to 2.5Gbps i226v adapter`

**Linux (kernel-native):**

- **Linux Bridge** — software switch, connects VMs/containers to a physical NIC. Simple, low overhead, what Proxmox uses by default (`vmbr0`)
- **Linux Bond** — combines multiple NICs into one logical interface for redundancy or throughput (LACP, active-backup, etc.)
- **Linux VLAN** — tags traffic on a bridge or interface with 802.1q VLAN IDs; "VLAN aware" on a bridge lets it handle multiple VLANs without separate interfaces

**OVS (Open vSwitch):**

- **OVS Bridge** — software-defined switch with advanced flow control, OpenFlow support, better for complex SDN setups
- **OVS Bond** — like Linux bond but managed within OVS, supports LACP natively with better integration
- **OVS IntPort** — internal virtual port on an OVS bridge; used to give the host itself an IP on that bridge (equivalent to the IP you'd put directly on a Linux bridge)

**TL;DR:** stick with Linux bridges. OVS adds complexity only worth it for SDN/multi-tenant enterprise networking. You don't need it.

## VM Configuration in Proxmox (template)
- General:
    - **node:** `whatever node`
    - **VM ID:** `select something high for a template 900?`
    - **Name:** `ubuntu-26.04-server-cloud-template`
    - **Start at boot:** - **`UNCHECK`**
- **OS:**
    - **Do not use any media** - **`CHECK`**
        - (using a cloud image, not an iso, so there's no reason to add media)
- **System:**
    - **Graphic Card:** Default
        - Guest GPU handles display; host-side graphic emulation is irrelevant
    - **Machine:** q35
        - Required for PCIe passthrough
    - **Firmware/BIOS:** OVMF (UEFI)
        - Required for q35 and modern GPU passthrough
    - **Add EFI Disk:** Yes
        - Required by OVMF
    - **EFI Storage:** local-lvm
        - Store EFI vars on your thin pool
    - **Pre-Enroll Keys:** No
        - Secure Boot will block unsigned ROCm/amdgpu drivers
    - **SCSI Controller:** VirtIO SCSI Single
        - Best performance for Linux guests
    - **QEMU Agent:** Yes
        - Enables clean shutdown, IP reporting, and snapshot coordination from Proxmox
    - **Add TPM:** No
        - Unnecessary overhead for a server VM
- **For the template - Just delete the disk**
- **Disks:**
    - **Bus/Device:** `SCSI 0`
        - VirtIO SCSI is best for Linux
    - **Cache:** `Default (No cache)`
        - Safest for data integrity; host page cache handles caching
    - **Discard:** - `CHECK`
        - Passes TRIM through to LVM thin pool, reclaims unused blocks
    - **Storage:** `local-lvm`
        - Use your thin pool, not local
    - **Disk size:** `32`
        - Fine for a template; expand on cloned VMs as needed
    - **Format:** `QEMU image format`
        - Correct for LVM-thin, leave it
    - **IO thread:** `Enabled`
        - Dedicated I/O thread per disk, better performance
    - **SSD Emulation:** `Enabled`
        - Tells guest it's an SSD, improves I/O scheduling
    - **Async IO:** `Default (io_uring)`
        - Best async I/O backend on modern kernels
    - **Backup:** `Enabled`
        - Include disk in Proxmox backups
    - **Read-only:** `No`
    - **Skip Replication:** `No`
**Note:** Change Storage from `local` to `local-lvm` — local stores raw files, local-lvm uses your thin pool properly.

- **CPU:**
    - **Sockets:** `1`
        - Single socket matches your physical CPU
    - **Cores:** `20`
        - Leaves 4 logical cores for Proxmox host
    - **Type:** `host`
        - Exposes real CPU flags to guest — required for ROCm
    - **Total Cores:** `14` (read-only, confirms sockets × cores)
    - **VCPUs:** `14`
        - Match cores
    - **CPU Units:** `1024`
        - Default; adjust if you add competing VMs
    - **CPU Limit:** `0` (unlimited)
        - Don't throttle your inference server
    - **Enable NUMA:** *`UNCHECK`*
        - Only 1 socket, no reason to use NUMA.
    - **CPU Affinity:** leave blank
        - Not needed unless you have multiple VMs competing for cores
- **Memory:**
    - **Memory:** `2048` (2GB)
        - Set properly on cloned VM, not template
    - **Minimum Memory:** `2048`
        - Match maximum — disable ballooning on inference server
    - **Ballooning Device:** *`UNCHECK`*
        - Ballooning causes memory pressure during inference; fixed allocation is better
    - **Allow KSM:** *`UNCHECK`*
        - KSM (same-page merging) is a security risk and adds overhead; not worth it for a single VM
- **Network**
    - **Bridge:** `vmbr0`
        - Template can start with mgmt bridge
    - **Model:** `VirtIO (paravirtualized)`
        - Best performance on Linux guests
    - **VLAN Tag:** leave blank
        - Handle VLANs inside the VM or at the bridge level
    - **Firewall:** *`UNCHECK`*
        - Proxmox firewall adds overhead; manage via your network instead
    - **MAC Address:** `auto-generate`
    - **Disconnect:** *`UNCHECK`*
    - **MTU:** leave blank
        - i226-V supports jumbo frames; set to `9000` later if your network supports it
    - **Rate Limit:** leave blank
    - **Multiqueue:** `4`
        - Set to number of vCPUs up to 8; improves network throughput for multi-threaded workloads

**Go ahead and create the VM - MAKE SURE TO UNCHECK START**

- **900 (ubuntu26.04-server-cloud-template)**
    - **Hardware**
        - **Add** -> **Cloud-iniit Drive**
            - **Storage:** - `local-lvm` -> **Add**


## Need to run: 

- `qm set <vm number> --serial0 socket --vga serial0`
- Make sure the image is `.qcow2` not `.img`
- `/var/lib/vz/template/iso/ubuntu26.04-server-cloudimg.qcow2`

```bash
qm importdisk <vmid> /var/lib/vz/template/iso/ubuntu26.04-server-cloudimg.qcow2 local-lvm
```

Replace `<vmid>` with your VM's ID number. After it completes, go to the VM's Hardware tab, find the unused disk, double-click it and add it as `scsi0`.

- **Discard** - `CHECK`
- **SSD Emulation** - `CHECK`

`qm importdisk` does three things:

- **Converts** the qcow2 image into the target storage format (raw LVM volume in this case)
- **Allocates** a new LVM volume on `local-lvm` sized to the image
- **Registers** it as an unused disk on the VM, ready to be attached as `scsi0`

It does not resize — the disk will be whatever size the cloud image is (~3-4GB). That's why you attach it first, then resize to 32G.

After importing, resize via Proxmox GUI or:

```bash
qm resize <vmid> scsi0 32G
```

- **900 (ubuntu26.04-server-cloud-template)**
    - **Options**
        - **Boot Order** -> `Enable` scsi0 and move it to position 2

**Gotcha:** with OVMF you need an EFI disk. Proxmox will prompt you to add one when you select OVMF — do it.

**Gotcha:** if the VM boots but the GPU isn't visible inside it, the most common cause is the IOMMU group issue from step 3 above, not a driver problem.

# Convert to template

---

## Assign cloud init drive to clone of template

- **Linked clone** — shares the template's disk, only stores differences. Fast to create, saves space, but dependent on the template existing. Can't delete the template while linked clones exist.
- **Full clone** — completely independent copy. Takes more space and time to create, but fully standalone.

For a server you're relying on: **full clone**.

```bash
# Clone the template
qm clone <templateid> <newvmid> --name ai-server --full

# Attach your cloud-init snippet
qm set <newvmid> --cicustom "user=local:snippets/your-cloud-init.yaml"

# Resize disk
qm resize <newvmid> scsi0 32G
```

- Change everything to how you want it to be.

- Change size, RAM, GPU pass through, bridge, ect

- **Add PCI Device:** select the R9700, check **All Functions**, check **ROM-Bar**, check **PCI-Express**
- Do NOT check "Primary GPU" in Proxmox unless you have no other display output — this can cause boot issues

After cloning:

```bash
# Find your GPU PCI address
lspci | grep AMD

# Add GPU to the cloned VM
qm set <vmid> --hostpci0 0000:05:00.0,pcie=1,x-vga=0

# Add audio function
qm set <vmid> --hostpci1 0000:05:00.1,pcie=1
```

**Flags:**
- `pcie=1` — exposes as PCIe not PCI, required for modern GPUs
- `x-vga=0` — don't use as primary display; you want SSH/network access, not a framebuffer

Then verify with:
```bash
qm config <vmid> | grep hostpci
```

```bash
cat /etc/pve/storage.cfg
```

- There is no `snippets`, need to add it

**Need to run:**

- `pvesm set local --content snippets,iso,vztmpl`
- `qm set <vm-id> --cicustom "user=local:snippets/cloud-init.yaml`
- `qm cloudinit dump <vm-id> user`

**You will probably lose you mind trying to get `qm cloudinit dump <vm-id> <type>` to output what is should. It doesn't, but the cloud-init you set still works**

Once the VM is booting and you can see the GPU with `lspci` inside the guest, *then* install ROCm. Installing ROCm before confirming passthrough works just adds noise to debugging.

## Once the VM is on you need to do the following

```bash
sudo apt install linux-firmware
sudo update-initramfs -u
sudo reboot
```

```bash
sudo apt install rocm
```

- go to [https://github.com/Umio-Yasuno/amdgpu_top/releases](https://github.com/Umio-Yasuno/amdgpu_top/releases)
- And get the without gui .deb image

`wget <link to the .deb>`

## Network Configuration

* **Management Interface:** Onboard Intel 1Gbps NIC
* **Hostname:** `${PVE06_HOSTNAME}`
* **IP Address:** `${PVE06_IP}`
* **Gateway:** `${PVE06_GATEWAY}`
* **DNS:** `${PVE06_DNS}`


