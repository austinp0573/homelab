#!/usr/bin/env bash
set -e

# Exit immediately if running unprivileged
if [ "$EUID" -ne 0 ]; then
  echo "error - This script must be run as root"
  exit 1
fi

echo "starting nvme optimization"

# Configurable Journald defaults (overridable via environment variables)
JOURNAL_STORAGE="${JOURNAL_STORAGE:-persistent}"
JOURNAL_SYNC_INTERVAL_SEC="${JOURNAL_SYNC_INTERVAL_SEC:-300s}"
JOURNAL_SYSTEM_MAX_USE="${JOURNAL_SYSTEM_MAX_USE:-64M}"
JOURNAL_MAX_RETENTION_SEC="${JOURNAL_MAX_RETENTION_SEC:-1month}"
JOURNAL_RATE_LIMIT_INTERVAL_SEC="${JOURNAL_RATE_LIMIT_INTERVAL_SEC:-30s}"
JOURNAL_RATE_LIMIT_BURST="${JOURNAL_RATE_LIMIT_BURST:-1000}"

# 1. Clean up log2ram if installed or configured
echo "Checking for log2ram cleanup..."
if command -v log2ram &>/dev/null || [ -f /etc/log2ram.conf ] || [ -f /etc/systemd/system/log2ram.service ] || dpkg -l | grep -q "^ii[[:space:]]\+log2ram"; then
  echo "log2ram detected. Cleaning up..."

  # Stop and disable service
  systemctl stop log2ram 2>/dev/null || true
  systemctl disable log2ram 2>/dev/null || true

  # Safely unmount log2ram mount points if active
  if mountpoint -q /var/log; then
    echo "Unmounting log2ram /var/log mount..."
    umount -l /var/log 2>/dev/null || true
  fi

  # Purge log2ram package if installed via APT
  if dpkg -l | grep -q "^ii[[:space:]]\+log2ram"; then
    echo "Purging log2ram package..."
    apt-get purge -y log2ram || true
  fi

  # Remove repository & keyring files
  rm -f /etc/apt/sources.list.d/azlux.list
  rm -f /usr/share/keyrings/azlux-archive-keyring.gpg

  # Remove config and leftover state files
  rm -f /etc/log2ram.conf
  rm -rf /var/log2ram

  # Refresh APT cache if repository was present
  apt-get update -qq || true
  echo "log2ram cleanup complete."
else
  echo "log2ram is not present. Skipping cleanup."
fi

# 2. Idempotent fstab update (disable access time metadata)
if ! grep -q "noatime" /etc/fstab; then
  echo "Updating /etc/fstab to include noatime..."
  sed -i.bak '/\(ext4\|xfs\|btrfs\)/ {/noatime/! s/\(defaults\|errors=remount-ro\|rw\)/\1,noatime/}' /etc/fstab
  mount -o remount / || true
else
  echo "/etc/fstab already optimized with noatime."
fi

# 3. Systemd journal configuration (persistent with write wear optimization)
echo "Configuring systemd journald for optimized SSD wear..."
rm -f /etc/systemd/journald.conf.d/99-volatile-ssd.conf
mkdir -p /etc/systemd/journald.conf.d
cat << EOF > /etc/systemd/journald.conf.d/99-ssd-wear.conf
[Journal]
Storage=${JOURNAL_STORAGE}
SyncIntervalSec=${JOURNAL_SYNC_INTERVAL_SEC}
SystemMaxUse=${JOURNAL_SYSTEM_MAX_USE}
MaxRetentionSec=${JOURNAL_MAX_RETENTION_SEC}
RateLimitIntervalSec=${JOURNAL_RATE_LIMIT_INTERVAL_SEC}
RateLimitBurst=${JOURNAL_RATE_LIMIT_BURST}
EOF
systemctl restart systemd-journald

# 4. Kernel Sysctl Optimization (Minimize Paging/Swapping and write frequency)
echo "Applying sysctl swappiness and dirty writeback ratios..."
cat << 'EOF' > /etc/sysctl.d/99-ssd-wear.conf
vm.swappiness = 1
vm.dirty_writeback_centisecs = 6000
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
EOF
sysctl --system >/dev/null

# 5. Enable Weekly SSD Trim
echo "Enabling standard fstrim timer..."
systemctl enable --now fstrim.timer

# 6. Tmpfs for /tmp directory to reduce writes
if ! grep -q -E "^tmpfs[[:space:]]+/tmp\b" /etc/fstab; then
  echo "Mounting /tmp as tmpfs..."
  echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab
  mount /tmp || true
else
  echo "/tmp is already mounted as tmpfs defined in /etc/fstab."
fi

# 7. Conditional Proxmox VE Optimization
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

  # Tune rrdcached flush intervals if /etc/default/rrdcached exists
  if [ -f /etc/default/rrdcached ]; then
    echo "Tuning rrdcached flush intervals to minimize disk writes..."
    if grep -q "^WRITE_TIMEOUT=" /etc/default/rrdcached; then
      sed -i 's/^WRITE_TIMEOUT=.*/WRITE_TIMEOUT=1800/' /etc/default/rrdcached
    else
      echo 'WRITE_TIMEOUT=1800' >> /etc/default/rrdcached
    fi
    if grep -q "^FLUSH_TIMEOUT=" /etc/default/rrdcached; then
      sed -i 's/^FLUSH_TIMEOUT=.*/FLUSH_TIMEOUT=3600/' /etc/default/rrdcached
    else
      echo 'FLUSH_TIMEOUT=3600' >> /etc/default/rrdcached
    fi
    systemctl restart rrdcached 2>/dev/null || true
  fi
fi

echo "NVMe optimization complete. A system reboot is recommended to ensure all journald, sysctl, and mount changes take full effect!"