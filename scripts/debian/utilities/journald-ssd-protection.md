# Native Systemd Journald SSD Protection Guide

This guide describes how to configure systemd's native `journald` daemon on modern Debian/Ubuntu systems to minimize SSD write wear without using legacy third-party tools like `log2ram`.

---

## Step 1: Remove `rsyslog` (Optional but Recommended)

Modern Debian systems use `journald` for all logging. `rsyslog` duplicates logs to plain text files in `/var/log`, causing unnecessary disk writes.

```bash
# Disable and purge rsyslog if installed
if dpkg -s rsyslog >/dev/null 2>&1; then
    sudo systemctl stop rsyslog
    sudo systemctl disable rsyslog
    sudo apt purge -y rsyslog
fi
```

---

## Step 2: Create a Journald SSD Optimization Drop-in

Rather than editing `/etc/systemd/journald.conf` directly, create a clean drop-in configuration file in `/etc/systemd/journald.conf.d/`:

```bash
# Create drop-in directory
sudo mkdir -p /etc/systemd/journald.conf.d

# Apply low-wear persistent journal configuration
sudo bash -c 'cat > /etc/systemd/journald.conf.d/99-ssd-wear.conf << EOF
[Journal]
Storage=persistent
SyncIntervalSec=5m
SystemMaxUse=50M
MaxRetentionSec=7day
EOF'
```

---

## Step 3: Apply Configuration

Restart `systemd-journald` to activate the new settings:

```bash
sudo systemctl restart systemd-journald
```

Verify journal status and active limits:
```bash
journalctl --disk-usage
```

---

## Configuration Parameter Reference & Goal Tuning

The following `journald` settings control disk write frequency and space consumption. Adjust them depending on your operational goals:

### Key Settings Explained

* **`Storage=`**
  * `persistent` *(Default)*: Stores logs on disk under `/var/log/journal/`.
  * `volatile`: Stores logs exclusively in RAM (`tmpfs`) under `/run/log/journal/`. Log writes to disk are **100% eliminated**, but logs are lost on reboot.
  * `auto`: Writes to disk if `/var/log/journal/` exists; otherwise stores in memory.

* **`SyncIntervalSec=`** *(Default: `5m`)*
  * Controls how frequently unwritten journal buffers are flushed from RAM to disk.
  * Setting to `5m` (5 minutes) or `10m` groups log writes into rare, batched operations, reducing SSD write amplification.

* **`SystemMaxUse=`** *(Default: `10%` of filesystem)*
  * Caps the maximum total disk space `/var/log/journal` can consume.
  * Setting to `50M` prevents log spikes from wearing out disk space or filling storage.

* **`MaxRetentionSec=`**
  * Controls how long logs are kept before being automatically deleted.
  * Examples: `7day`, `1month`, `2weeks`.

* **`MaxFileSec=`**
  * Controls how often journal log files rotate. Setting a larger interval (e.g., `1month`) prevents frequent file allocation metadata writes.

---

### Recommended Settings by Use-Case

#### Goal A: Maximum SSD Lifespan + Crash Survival (Recommended for Homelabs)
Batches writes to RAM every 5 minutes and caps total log usage at 50MB.

```ini
[Journal]
Storage=persistent
SyncIntervalSec=5m
SystemMaxUse=50M
MaxRetentionSec=7day
```

#### Goal B: Zero SSD Wear (RAM-Only / Volatile Logging)
Completely eliminates log writes to disk. Logs are stored purely in memory and cleared on reboot.

```ini
[Journal]
Storage=volatile
RuntimeMaxUse=64M
```

#### Goal C: Extended History with Controlled Space
Maintains up to 30 days of logs while enforcing a strict 200MB disk cap.

```ini
[Journal]
Storage=persistent
SyncIntervalSec=5m
SystemMaxUse=200M
MaxRetentionSec=30day
```
