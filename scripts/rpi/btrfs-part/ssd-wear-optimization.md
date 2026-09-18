# Post-Boot SSD Wear Optimization Guide (BTRFS on Raspberry Pi OS)

This guide details all actions to take **after booting into your new NVMe BTRFS installation** to absolutely minimize SSD write wear and prolong drive endurance without breaking system stability or BTRFS capabilities.

---

## Step 1: Verify Active BTRFS Mount Options

Verify that your subvolumes are mounted with the write-reducing options configured in `/etc/fstab`:

```bash
mount | grep btrfs
```

Ensure `noatime`, `commit=60`, `discard=async`, and `space_cache=v2` appear in the output.

---

## Step 2: Configure Systemd Journald to Limit Disk Writes

By default, systemd writes logs continuously to disk. Cap log sizes and buffer flushes:

Create a drop-in configuration for journald:

```bash
sudo mkdir -p /etc/systemd/journald.conf.d

sudo bash -c 'cat > /etc/systemd/journald.conf.d/99-ssd-wear.conf << EOF
[Journal]
Storage=persistent
SystemMaxUse=50M
SyncIntervalSec=5m
MaxRetentionSec=7day
EOF'

# Restart journald to apply
sudo systemctl restart systemd-journald
```

*(Optional)* If you want to eliminate log writes to disk completely, change `Storage=persistent` to `Storage=volatile` (stores logs strictly in RAM).

---

## Step 3: Configure ZRAM (Primary) & Emergency NVMe Swapfile (Fallback)

Raspberry Pi OS Lite includes `systemd-zram-generator` built-in, but caps `/dev/zram0` at 2GB by default via `/usr/lib/systemd/zram-generator.conf.d/20-rpi-swap-zram0-ctrl.conf`. Override this default with native `systemd-zram-generator` drop-in configuration to allocate 50% RAM (`pri=100`) as primary ZRAM, backed by a low-priority emergency NVMe `/swapfile` (`pri=10`):

```bash
# 1. Disable legacy SD/NVMe swap file daemon if present
sudo systemctl stop dphys-swapfile 2>/dev/null || true
sudo systemctl disable dphys-swapfile 2>/dev/null || true
sudo apt purge -y dphys-swapfile 2>/dev/null || true
sudo rm -f /var/swap

# 2. Disable legacy zram-tools service if installed to prevent conflicts
sudo systemctl stop zramswap 2>/dev/null || true
sudo systemctl disable zramswap 2>/dev/null || true

# 3. Create systemd zram-generator drop-in directory
sudo mkdir -p /etc/systemd/zram-generator.conf.d

# 4. Overwrite Pi OS default 2GB cap with 50% RAM ZRAM configuration
sudo bash -c 'cat > /etc/systemd/zram-generator.conf.d/20-rpi-swap-zram0-ctrl.conf << EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF'

# 5. Apply ZRAM generator settings
sudo swapoff /dev/zram0 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0

# 6. Create BTRFS-compliant emergency low-priority NVMe swapfile (2GB)
sudo truncate -s 0 /swapfile
sudo chattr +C /swapfile
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile

# Add /swapfile to /etc/fstab with pri=10 if not present
if ! grep -q "^/swapfile " /etc/fstab; then
    echo "/swapfile none swap sw,pri=10 0 0" | sudo tee -a /etc/fstab
fi

# Activate low-priority emergency swapfile
sudo swapon -p 10 /swapfile
```

Verify dual-tier swap configuration:
```bash
zramctl
swapon --show
```
*(You should see `zram0` at 50% RAM with `pri=100` and `/swapfile` with `pri=10`).*

> [!NOTE]
> **Why `/etc/systemd/zram-generator.conf.d/`?**:
> Raspberry Pi OS ships its default 2GB ZRAM cap in `/usr/lib/systemd/zram-generator.conf.d/20-rpi-swap-zram0-ctrl.conf`. Creating the matching file in `/etc/systemd/zram-generator.conf.d/` permanently overrides it without risking package update overwrites.

---

## Step 4: Tune Kernel Memory Writes (sysctl)

Adjust kernel parameters to delay dirty page writes and reduce swappiness:

```bash
sudo bash -c 'cat > /etc/sysctl.d/99-ssd-wear.conf << EOF
# Prefer RAM over swap
vm.swappiness = 10

# Delay flushing dirty cache pages to disk (60 seconds)
vm.dirty_writeback_centisecs = 6000
vm.dirty_expire_centisecs = 6000

# Keep small dirty memory ratios
vm.dirty_background_ratio = 5
vm.dirty_ratio = 15
EOF'

# Apply sysctl settings immediately
sudo sysctl --system
```

---

## Step 5: Disable Redundant System Logging Services

If `rsyslog` is installed, it duplicate-logs system events alongside `journald`. Remove it:

```bash
if dpkg -s rsyslog >/dev/null 2>&1; then
    sudo systemctl stop rsyslog
    sudo systemctl disable rsyslog
    sudo apt purge -y rsyslog
fi
```

---

## Step 6: Apply NOCOW (`chattr +C`) to High-Write Container/App Folders

Copy-on-Write (CoW) causes write amplification on files with high random overwrites (such as SQLite, PostgreSQL, MySQL, or log files in `/opt`).

Set the `NOCOW` attribute on service data directories **before** files are created:

```bash
# Example for a specific container data directory in /opt
sudo mkdir -p /opt/my-service/data
sudo chattr +C /opt/my-service/data

# Verify +C attribute is set (indicated by "C" flag)
lsattr -d /opt/my-service/data
```

---

## Step 7: Configure & Verify Asynchronous TRIM / Discard

BTRFS is mounted with `discard=async` to stream TRIM requests in the background. As a backup safety net, configure systemd's `fstrim.timer` to run weekly (the optimal frequency for SSD endurance):

```bash
# 1. Run an immediate manual TRIM to clean unused blocks
sudo fstrim -v /

# 2. Configure fstrim.timer override (Weekly schedule)
sudo mkdir -p /etc/systemd/system/fstrim.timer.d

sudo bash -c 'cat > /etc/systemd/system/fstrim.timer.d/override.conf << EOF
[Timer]
OnCalendar=
OnCalendar=Mon *-*-* 03:00:00
EOF'

# 3. Reload systemd and enable timer
sudo systemctl daemon-reload
sudo systemctl enable --now fstrim.timer
```

Verify timer status and next scheduled run:
```bash
systemctl status fstrim.timer
```

> [!NOTE]
> **Optimal TRIM Frequency**: **Weekly** is the industry standard. Trimming more frequently (e.g., hourly) increases SSD controller processing overhead, while trimming less frequently (e.g., monthly) allows deleted block buildup. BTRFS `discard=async` handles real-time cleanup, while the weekly timer catches any remaining blocks.

---

## Step 8: Verify System Wear Reduction Status

Check overall swap, RAM, and mount status:

```bash
# Check memory and swap usage
free -h

# Check BTRFS error and write statistics
sudo btrfs device stats /
```
