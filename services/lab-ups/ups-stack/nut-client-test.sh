#!/bin/sh
set -eu

UPS_NAME="${UPS_NAME:-lab_apc}"
NUT_MON_USER="${NUT_MON_USER:-monuser}"
NUT_SERVER="${NUT_SERVER:-${1:-}}"
NUT_MON_PASSWORD="${NUT_MON_PASSWORD:-${2:-}}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0 <nut-server-ip> <nut-monitor-password>" >&2
  exit 1
fi

if [ -z "${NUT_SERVER}" ] || [ -z "${NUT_MON_PASSWORD}" ]; then
  echo "Usage: sudo $0 <nut-server-ip> <nut-monitor-password>" >&2
  echo "Optional env: UPS_NAME=${UPS_NAME} NUT_MON_USER=${NUT_MON_USER}" >&2
  exit 1
fi

if command -v apt-get >/dev/null 2>&1; then
  apt-get update
  apt-get install -y nut-client
else
  echo "This test script currently supports apt-based systems only." >&2
  exit 1
fi

mkdir -p /etc/nut

for file in /etc/nut/nut.conf /etc/nut/upsmon.conf; do
  if [ -f "${file}" ] && [ ! -f "${file}.ups-stack-test.bak" ]; then
    cp "${file}" "${file}.ups-stack-test.bak"
  fi
done

cat > /etc/nut/nut.conf <<'EOF'
MODE=netclient
EOF

cat > /etc/nut/upsmon.conf <<EOF
MONITOR ${UPS_NAME}@${NUT_SERVER} 1 ${NUT_MON_USER} ${NUT_MON_PASSWORD} slave

MINSUPPLIES 1
SHUTDOWNCMD "/sbin/shutdown -h now"
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
POWERDOWNFLAG /etc/killpower

RBWARNTIME 43200
NOCOMMWARNTIME 300
FINALDELAY 5
EOF

chmod 640 /etc/nut/upsmon.conf

if systemctl list-unit-files nut-client.service >/dev/null 2>&1; then
  systemctl enable --now nut-client
  systemctl restart nut-client
elif systemctl list-unit-files nut-monitor.service >/dev/null 2>&1; then
  systemctl enable --now nut-monitor
  systemctl restart nut-monitor
else
  systemctl restart nut-client 2>/dev/null || systemctl restart nut-monitor 2>/dev/null || true
fi

echo "NUT client configured for ${UPS_NAME}@${NUT_SERVER}."
echo "Test with: upsc ${UPS_NAME}@${NUT_SERVER}"
