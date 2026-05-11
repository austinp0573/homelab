#!/bin/bash
set -e

echo "=== Configuring Proxmox host for minimal NVMe I/O ==="

# 1. noatime on all ext4/xfs mounts
sed -i 's/\(errors=remount-ro\)/noatime,\1/g' /etc/fstab
sed -i 's/\(defaults\)/noatime,\1/g' /etc/fstab

# 2. tmpfs for /tmp
if ! grep -q "tmpfs /tmp" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab
fi

# 3. sysctl tweaks
cat << 'EOF' > /etc/sysctl.d/99-io-tweaks.conf
vm.dirty_writeback_centisecs=6000
vm.dirty_ratio=40
vm.dirty_background_ratio=10
EOF
sysctl -p /etc/sysctl.d/99-io-tweaks.conf

# 4. Install and configure log2ram
if ! command -v log2ram &>/dev/null; then
    echo "deb [signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian/ stable main" > /etc/apt/sources.list.d/azlux.list
    wget -qO /usr/share/keyrings/azlux-archive-keyring.gpg https://azlux.fr/repo.gpg
    apt update && apt install -y log2ram
fi

# Set log2ram size to 128MB and include pve-manager path
sed -i 's/SIZE=.*/SIZE=128M/' /etc/log2ram.conf
sed -i 's|PATH_DISK=.*|PATH_DISK="/var/log;/var/lib/pve-manager"|' /etc/log2ram.conf

systemctl enable log2ram

echo "=== Done. Reboot to apply all changes ==="