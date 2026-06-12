#!/bin/sh
# Idempotent UpSnap shutdown user provisioning script.
# Safely executes multiple times; applies changes only if state drifts.
# run with: sudo bash -c 'set -a; source .env; exec ./setup-upsnap-shutdown-user.sh'
set -eu

UPSNAP_USER="${UPSNAP_USER:-upsnap-shutdown}"
UPSNAP_PUBLIC_KEY="${UPSNAP_PUBLIC_KEY:-}"
SHUTDOWN_COMMAND="${SHUTDOWN_COMMAND:-/sbin/shutdown -h now}"

if [ -z "$UPSNAP_PUBLIC_KEY" ]; then
  echo "Usage:"
  echo "  sudo UPSNAP_PUBLIC_KEY='<contents of upsnap_shutdown_key.pub>' $0"
  exit 1
fi

ACTION_TAKEN=0

# 1. Idempotent Sudo Installation
if ! command -v sudo >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y sudo
    ACTION_TAKEN=1
  else
    echo "sudo is required and this script only auto-installs it on apt-based hosts."
    exit 1
  fi
fi

# 2. Idempotent User Creation
if ! id "$UPSNAP_USER" >/dev/null 2>&1; then
  useradd --system --create-home --shell /bin/sh "$UPSNAP_USER"
  ACTION_TAKEN=1
fi

# Helper function to conditionally replace files
update_config() {
  local target_file="$1"
  local tmp_file="$2"
  local file_mode="$3"

  if [ ! -f "$target_file" ] || ! cmp -s "$target_file" "$tmp_file"; then
    mv "$tmp_file" "$target_file"
    chmod "$file_mode" "$target_file"
    ACTION_TAKEN=1
  else
    rm "$tmp_file"
  fi
}

home_dir="$(getent passwd "$UPSNAP_USER" | cut -d: -f6)"
mkdir -p "$home_dir/.ssh"
chown "$UPSNAP_USER:$UPSNAP_USER" "$home_dir/.ssh"
chmod 700 "$home_dir/.ssh"

# 3. Idempotent SSH Key Provisioning with Restrictions
TMP_SSH_KEY=$(mktemp)
# Adding execution restrictions to the key prevents tunnel/shell abuse
printf 'no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty %s\n' "$UPSNAP_PUBLIC_KEY" > "$TMP_SSH_KEY"
update_config "$home_dir/.ssh/authorized_keys" "$TMP_SSH_KEY" 600
chown "$UPSNAP_USER:$UPSNAP_USER" "$home_dir/.ssh/authorized_keys"

# 4. Safe, Idempotent Sudoers Provisioning
TMP_SUDOERS=$(mktemp)
cat > "$TMP_SUDOERS" <<EOF
$UPSNAP_USER ALL=(root) NOPASSWD: $SHUTDOWN_COMMAND
EOF

visudo_bin=""
for candidate in /usr/sbin/visudo /sbin/visudo visudo; do
  if command -v "$candidate" >/dev/null 2>&1; then
    visudo_bin="$(command -v "$candidate")"
    break
  fi
done

sudoers_file="/etc/sudoers.d/90-upsnap-shutdown"

if [ -n "$visudo_bin" ]; then
  # Validate the file while it is still safely in /tmp
  if "$visudo_bin" -cf "$TMP_SUDOERS" >/dev/null 2>&1; then
    update_config "$sudoers_file" "$TMP_SUDOERS" 440
  else
    rm "$TMP_SUDOERS"
    echo "Error: Sudoers syntax validation failed. Aborting before system is damaged."
    exit 1
  fi
else
  echo "Warning: visudo not found; writing sudoers blindly."
  update_config "$sudoers_file" "$TMP_SUDOERS" 440
fi

if [ "$ACTION_TAKEN" -eq 1 ]; then
  echo "Changes applied. UpSnap user and permissions configured."
else
  echo "State matched desired configuration. No changes required."
fi