#!/bin/sh
# Idempotent NUT client provisioning script.
# Safely executes multiple times; applies changes and restarts only if state drifts.
# in the same directory as a copy of the .env that is properly populated for the client run:
# sudo bash -c 'set -a; source .env; exec ./setup-nut-client.sh'
set -eu

NUT_SERVER="${NUT_SERVER:-}"
UPS_NAME="${UPS_NAME:-myups}"
NUT_CLIENT_USER="${NUT_CLIENT_USER:-clientmon}"
NUT_CLIENT_PASSWORD="${NUT_CLIENT_PASSWORD:-}"
NUT_FINAL_DELAY="${NUT_FINAL_DELAY:-5}"

if [ -z "$NUT_SERVER" ] || [ -z "$NUT_CLIENT_PASSWORD" ]; then
  echo "Usage:"
  echo "  sudo NUT_SERVER=<nanopi-ip> UPS_NAME=<ups-name> NUT_CLIENT_PASSWORD=<password> NUT_FINAL_DELAY=<seconds> $0"
  exit 1
fi

# Track if any state modification requires a daemon restart
NEEDS_RESTART=0

# 1. Idempotent Package Installation
if ! dpkg -s nut-client >/dev/null 2>&1; then
  apt-get update
  apt-get install -y nut-client
  NEEDS_RESTART=1
fi

# 2. Idempotent Tmpfiles Patch
TMPFILE_CONF="/usr/lib/tmpfiles.d/nut-common-tmpfiles.conf"
if [ ! -f "$TMPFILE_CONF" ]; then
  cat > "$TMPFILE_CONF" << 'EOF'
d /run/nut 0770 nut nut - -
EOF
  systemd-tmpfiles --create "$TMPFILE_CONF"
  NEEDS_RESTART=1
fi

mkdir -p /etc/nut

# Helper function to update target file only if temporary render differs
update_config() {
  local target_file="$1"
  local tmp_file="$2"

  if [ ! -f "$target_file" ] || ! cmp -s "$target_file" "$tmp_file"; then
    # Backup pristine state once
    if [ -f "$target_file" ] && [ ! -f "${target_file}.orig" ]; then
      cp -a "$target_file" "${target_file}.orig"
    fi
    mv "$tmp_file" "$target_file"
    chmod 640 "$target_file"
    NEEDS_RESTART=1
  else
    rm "$tmp_file"
  fi
}

# 3. Idempotent nut.conf
TMP_NUT_CONF=$(mktemp)
cat > "$TMP_NUT_CONF" <<EOF
MODE=netclient
EOF
update_config "/etc/nut/nut.conf" "$TMP_NUT_CONF"

# 4. Idempotent upsmon.conf
TMP_UPSMON_CONF=$(mktemp)
cat > "$TMP_UPSMON_CONF" <<EOF
MONITOR ${UPS_NAME}@${NUT_SERVER} 1 ${NUT_CLIENT_USER} ${NUT_CLIENT_PASSWORD} slave
MINSUPPLIES 1
SHUTDOWNCMD "/sbin/shutdown -h now"
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
POWERDOWNFLAG /etc/killpower
FINALDELAY ${NUT_FINAL_DELAY}
EOF
update_config "/etc/nut/upsmon.conf" "$TMP_UPSMON_CONF"

# 5. Service State Convergence
systemctl enable nut-client >/dev/null 2>&1

if [ "$NEEDS_RESTART" -eq 1 ]; then
  systemctl daemon-reload
  systemctl restart nut-client
  echo "Changes applied. NUT client restarted."
else
  # Ensure the service is active without interrupting it
  systemctl start nut-client
  echo "State matched desired configuration. No restart required."
fi