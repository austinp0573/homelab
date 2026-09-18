# Raspberry Pi 5 NVMe BTRFS Setup Guide

This guide walks through partitioning, formatting, creating subvolumes, and migrating a running Raspberry Pi OS Lite installation from a MicroSD card (`/dev/mmcblk0`) to an NVMe drive (`/dev/nvme0n1`) with a hardened BTRFS filesystem.

---

## Prerequisites

Before starting, install the required filesystem tools and configure `initramfs` so the BTRFS kernel driver (`btrfs.ko`) is included in the boot image:

```bash
# Install required utilities
sudo apt update
sudo apt install -y btrfs-progs rsync dosfstools parted

# Explicitly add btrfs module to initramfs config
echo "btrfs" | sudo tee -a /etc/initramfs-tools/modules

# Rebuild initramfs so initrd.img contains btrfs.ko
sudo update-initramfs -u -k all

# Enable auto initramfs & NVMe overlay in boot config if missing
grep -q "auto_initramfs=1" /boot/firmware/config.txt || echo "auto_initramfs=1" | sudo tee -a /boot/firmware/config.txt
grep -q "dtparam=nvme" /boot/firmware/config.txt || echo "dtparam=nvme" | sudo tee -a /boot/firmware/config.txt
```

---

## Step 1: Partition the NVMe Drive (`/dev/nvme0n1`)

Wipe existing partition tables on `/dev/nvme0n1` and create a GPT partition layout:
- **Partition 1 (`/dev/nvme0n1p1`)**: 512MB FAT32 (Bootloader / Firmware)
- **Partition 2 (`/dev/nvme0n1p2`)**: Remaining space BTRFS (Root & Services)

```bash
# Create a new GPT disk label
sudo parted -s /dev/nvme0n1 mklabel gpt

# Create 512MB boot partition (FAT32)
sudo parted -s /dev/nvme0n1 mkpart primary fat32 1MiB 513MiB
sudo parted -s /dev/nvme0n1 set 1 boot on

# Create root partition using the rest of the drive (BTRFS)
sudo parted -s /dev/nvme0n1 mkpart primary btrfs 513MiB 100%
```

Verify partition creation:
```bash
sudo lsblk /dev/nvme0n1
```

---

## Step 2: Format Partitions

Format partition 1 as FAT32 and partition 2 as BTRFS:

```bash
# Format boot partition
sudo mkfs.vfat -F 32 -n "boot" /dev/nvme0n1p1

# Format root partition with BTRFS
sudo mkfs.btrfs -f -L "rootfs" /dev/nvme0n1p2
```

---

## Step 3: Create BTRFS Subvolumes

Mount the raw BTRFS filesystem temporarily and build the subvolume layout:

```bash
# Create temporary mount point for raw BTRFS top-level (subvolid=5)
sudo mkdir -p /mnt/btrfs-root
sudo mount /dev/nvme0n1p2 /mnt/btrfs-root

# Create subvolumes
sudo btrfs subvolume create /mnt/btrfs-root/@
sudo btrfs subvolume create /mnt/btrfs-root/@opt
sudo btrfs subvolume create /mnt/btrfs-root/@home
sudo btrfs subvolume create /mnt/btrfs-root/@containerd
sudo btrfs subvolume create /mnt/btrfs-root/@var_log
sudo btrfs subvolume create /mnt/btrfs-root/@snapshots

# Disable Copy-on-Write (CoW) for log directory to minimize SSD wear
sudo chattr +C /mnt/btrfs-root/@var_log

# Unmount raw BTRFS root
sudo umount /mnt/btrfs-root
```

---

## Step 4: Mount Subvolumes to Target Directory Structure

Mount the created subvolumes under `/mnt/target` in their target directory hierarchy:

```bash
# Create main target directory
sudo mkdir -p /mnt/target

# Mount root subvolume (@)
sudo mount -o noatime,commit=60,discard=async,space_cache=v2,subvol=@ /dev/nvme0n1p2 /mnt/target

# Create mount points inside root subvolume
sudo mkdir -p /mnt/target/{boot/firmware,opt,home,var/lib/containerd,var/log,.snapshots}

# Mount secondary subvolumes
sudo mount -o noatime,commit=60,discard=async,space_cache=v2,subvol=@opt /dev/nvme0n1p2 /mnt/target/opt
sudo mount -o noatime,commit=60,discard=async,space_cache=v2,subvol=@home /dev/nvme0n1p2 /mnt/target/home
sudo mount -o noatime,commit=60,discard=async,space_cache=v2,subvol=@containerd /dev/nvme0n1p2 /mnt/target/var/lib/containerd
sudo mount -o noatime,commit=60,discard=async,nodatacow,subvol=@var_log /dev/nvme0n1p2 /mnt/target/var/log
sudo mount -o noatime,commit=60,discard=async,space_cache=v2,subvol=@snapshots /dev/nvme0n1p2 /mnt/target/.snapshots

# Mount NVMe boot partition
sudo mount /dev/nvme0n1p1 /mnt/target/boot/firmware
```

Verify mount points:
```bash
df -h | grep /mnt/target
```

---

## Step 5: Rsync SD Card OS to NVMe Drive

Copy all system files from the MicroSD card to the NVMe subvolumes:

```bash
# Sync root filesystem (excluding pseudo-filesystems and target mount)
sudo rsync -axHAWX --numeric-ids --progress \
  --exclude=/proc/* \
  --exclude=/sys/* \
  --exclude=/dev/* \
  --exclude=/run/* \
  --exclude=/mnt/* \
  --exclude=/tmp/* \
  --exclude=/lost+found \
  / /mnt/target/

# Sync kernel, initramfs, and boot firmware files
sudo rsync -axHAWX --numeric-ids --progress /boot/ /mnt/target/boot/
sudo rsync -axHAWX --numeric-ids --progress /boot/firmware/ /mnt/target/boot/firmware/
```

---

## Step 6: Configure Boot & Filesystem Mounts (`fstab` and `cmdline.txt`)

Retrieve UUIDs of the NVMe partitions:

```bash
# Get UUIDs for nvme0n1p1 and nvme0n1p2
sudo blkid /dev/nvme0n1p1
sudo blkid /dev/nvme0n1p2
```

### Update `/mnt/target/etc/fstab`

Replace existing `/etc/fstab` on the NVMe with new BTRFS subvolume mount entries. Use your `nvme0n1p1` and `nvme0n1p2` UUIDs:

```text
# <file system>                           <mount point>        <type>  <options>                                             <dump> <pass>
UUID=<NVME_P2_UUID>                       /                    btrfs   noatime,commit=60,discard=async,space_cache=v2,subvol=@         0      0
UUID=<NVME_P2_UUID>                       /opt                 btrfs   noatime,commit=60,discard=async,space_cache=v2,subvol=@opt      0      0
UUID=<NVME_P2_UUID>                       /home                btrfs   noatime,commit=60,discard=async,space_cache=v2,subvol=@home     0      0
UUID=<NVME_P2_UUID>                       /var/lib/containerd  btrfs   noatime,commit=60,discard=async,space_cache=v2,subvol=@containerd 0    0
UUID=<NVME_P2_UUID>                       /var/log             btrfs   noatime,commit=60,discard=async,nodatacow,subvol=@var_log       0      0
UUID=<NVME_P2_UUID>                       /.snapshots          btrfs   noatime,commit=60,discard=async,space_cache=v2,subvol=@snapshots 0    0
UUID=<NVME_P1_UUID>                       /boot/firmware       vfat    defaults                                                        0      2
tmpfs                                     /tmp                 tmpfs   defaults,noatime,nosuid,nodev                                  0      0
```

### Update `/mnt/target/boot/firmware/cmdline.txt`

Edit `/mnt/target/boot/firmware/cmdline.txt` (must remain a single continuous line):

```text
console=serial0,115200 console=tty1 root=UUID=<NVME_P2_UUID> rootfstype=btrfs rootflags=subvol=@ rw rootwait
```

---

## Step 7: Configure Raspberry Pi 5 EEPROM to Boot NVMe

Set the boot order in EEPROM:

```bash
# Set BOOT_ORDER to try NVMe (6) first, SD card (1) second
sudo rpi-eeprom-config --set BOOT_ORDER=0xf416
```

Verify EEPROM boot order:
```bash
sudo rpi-eeprom-config
```
*(Note: Pending EEPROM changes apply upon the next reboot).*

---

## Step 8: Clean Unmount and Reboot

Unmount all NVMe targets safely:

```bash
sudo umount -R /mnt/target
```

Shut down the Pi, remove the MicroSD card, and power back on to boot directly from NVMe:

```bash
sudo poweroff
```

---

## Troubleshooting & Notes

### Emergency Exit from `(initramfs)` Shell Prompt
If the system drops to a `(initramfs)` prompt during boot, you can pivot back into the MicroSD card OS without pulling hardware:
```sh
mkdir -p /root
mount -t ext4 /dev/mmcblk0p2 /root
exit
```

### Error: `failed to open /dev/btrfs-control`
This indicates the `btrfs` module was omitted from `initramfs`. Ensure `echo "btrfs" >> /etc/initramfs-tools/modules` was executed and `sudo update-initramfs -u -k all` was run before copying `/boot/` to NVMe.

### Kernel Boots Back into MicroSD Card
If `lsblk` shows `/` is still on `mmcblk0p2` after rebooting:
Verify that `/boot/firmware/cmdline.txt` on the NVMe FAT32 partition has `root=UUID=<NVME_P2_UUID>` (pointing to `nvme0n1p2`), rather than the SD card PARTUUID.
