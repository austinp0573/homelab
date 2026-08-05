#!/usr/bin/env bash

# Exit immediately if running unprivileged
if [ "$EUID" -ne 0 ]; then
  echo "error - This script must be run as root"
  exit 1
fi

echo "starting nvme optimization"

# idempotent fstab update (disable access time metadata)
# backs up fstab
# then targets ext4, xfs, or btrfs lines
# If noatime is missing
# it appends it directly after 'defaults' or 'errors=remount-ro'
if ! grep -q "noatime" /etc/fstab; then
  echo "Updating /etc/fstab to include noatime..."
  sed -i.bak '/\(ext4\|xfs\|btrfs\)/ {/noatime/! s/\(defaults\|errors=remount-ro\|rw\)/\1,noatime/}' /etc/fstab
  mount -o remount /
else
  echo "/etc/fstab already optimized."
fi

# systemd journal optimization (volatile / RAM-backed logs)
echo "Configuring volatile systemd journal..."
mkdir -p /etc/systemd/journald.conf.d
cat << 'EOF' > /etc/systemd/journald.conf.d/99-volatile-ssd.conf
[Journal]
Storage=volatile
RuntimeMaxUse=64M
EOF
systemctl restart systemd-journald

# 3. Kernel Sysctl Optimization (Minimize Paging/Swapping)
echo "applying sysctl swappiness and high delay dirty ratios for minimal writes" 
cat << 'EOF' > /etc/sysctl.d/99-ssd-wear.conf
vm.swappiness = 1
vm.dirty_writeback_centisecs = 6000
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
EOF
sysctl --system >/dev/null

# 4. Enable Weekly SSD Trim
echo "Enabling standard fstrim timer..."
systemctl enable --now fstrim.timer

# 5. Tmpfs for /tmp directory to reduce writes
if ! grep -q -E "^tmpfs[[:space:]]+/tmp\b" /etc/fstab; then
  echo "Mounting /tmp as tmpfs..."
  echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab
  mount /tmp || true
else
  echo "/tmp is already mounted as tmpfs defined in /etc/fstab."
fi

# 6. Conditional Proxmox VE Optimization
if [ -x /usr/bin/pveversion ]; then
  echo "Proxmox VE detected."
  # If corosync.conf does not exist, this node is not part of a cluster.
  if [ ! -f /etc/pve/corosync.conf ]; then
    echo "Standalone node detected. Disabling HA and Corosync telemetry to save writes..."
    systemctl stop pve-ha-lrm pve-ha-crm corosync 2>/dev/null || true
    systemctl disable pve-ha-lrm pve-ha-crm corosync 2>/dev/null || true
  else
    echo "Cluster configuration found. Skipping HA disablement to prevent split-brain."
  fi
fi

# 7. Install and Configure log2ram (Idempotent)
echo "Setting up log2ram to minimize SSD writes..."
if ! command -v log2ram &>/dev/null; then
  echo "log2ram not found, installing..."
  wget -qO /usr/share/keyrings/azlux-archive-keyring.gpg https://azlux.fr/repo.gpg
  echo "deb [signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian/ stable main" > /etc/apt/sources.list.d/azlux.list
  apt-get update -qq && apt-get install -y log2ram
else
  echo "log2ram is already installed."
fi

# Configure log2ram size and mapped paths
if [ -f /etc/log2ram.conf ]; then
  # Increase RAM size allocation
  sed -i 's/^SIZE=.*/SIZE=512M/' /etc/log2ram.conf
  
  # Conditionally cache PVE specific directories if Proxmox is installed
  if [ -x /usr/bin/pveversion ]; then
    # /var/lib/pve-manager and /var/lib/rrdcached are high write directories in PVE
    sed -i 's|^PATH_DISK=.*|PATH_DISK="/var/log;/var/lib/pve-manager;/var/lib/rrdcached"|' /etc/log2ram.conf
  else
    sed -i 's|^PATH_DISK=.*|PATH_DISK="/var/log"|' /etc/log2ram.conf
  fi
  
  systemctl enable log2ram
fi

echo "NVMe optimization complete. A system reboot is strongly recommended to apply kernel and log2ram changes!"