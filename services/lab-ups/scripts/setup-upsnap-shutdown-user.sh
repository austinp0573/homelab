#!/bin/sh
# Creates the upsnap-shutdown system user on a target host and authorizes the UpSnap
# SSH key for it. Also drops a sudoers file so the user can run shutdown without a
# password — UpSnap SSHes in as this user and runs the shutdown command directly.
# Run as root on each host that UpSnap should be able to shut down.
set -eu

UPSNAP_USER="${UPSNAP_USER:-upsnap-shutdown}"
UPSNAP_PUBLIC_KEY="${UPSNAP_PUBLIC_KEY:-}"
SHUTDOWN_COMMAND="${SHUTDOWN_COMMAND:-/sbin/shutdown -h now}"

if [ -z "$UPSNAP_PUBLIC_KEY" ]; then
  echo "Usage:"
  echo "  sudo UPSNAP_PUBLIC_KEY='<contents of upsnap_shutdown_key.pub>' $0"
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y sudo
  else
    echo "sudo is required and this script only auto-installs it on apt-based hosts."
    exit 1
  fi
fi

# System user with no login shell — it only exists to be SSHed into for shutdown.
if ! id "$UPSNAP_USER" >/dev/null 2>&1; then
  useradd --system --create-home --shell /bin/sh "$UPSNAP_USER"
fi

home_dir="$(getent passwd "$UPSNAP_USER" | cut -d: -f6)"
mkdir -p "$home_dir/.ssh"
printf '%s\n' "$UPSNAP_PUBLIC_KEY" > "$home_dir/.ssh/authorized_keys"
chown -R "$UPSNAP_USER:$UPSNAP_USER" "$home_dir/.ssh"
chmod 700 "$home_dir/.ssh"
chmod 600 "$home_dir/.ssh/authorized_keys"

# Both /sbin and /usr/sbin paths are listed because Debian and Ubuntu differ on which
# one exists. UpSnap sends the command as configured; this covers both defaults.
sudoers="/etc/sudoers.d/90-upsnap-shutdown"
cat > "$sudoers" <<EOF
$UPSNAP_USER ALL=(root) NOPASSWD: /sbin/shutdown -h now, /usr/sbin/shutdown -h now
EOF
chmod 440 "$sudoers"

# visudo -c validates syntax before we walk away — a broken sudoers file can lock
# you out of sudo entirely.
visudo_bin=""
for candidate in /usr/sbin/visudo /sbin/visudo visudo; do
  if command -v "$candidate" >/dev/null 2>&1; then
    visudo_bin="$(command -v "$candidate")"
    break
  fi
done

if [ -n "$visudo_bin" ]; then
  "$visudo_bin" -cf "$sudoers"
else
  echo "Warning: visudo not found; sudoers file was written but not validated."
fi

echo "UpSnap shutdown user is ready."
echo "Configured command: sudo $SHUTDOWN_COMMAND"
