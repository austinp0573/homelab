#!/bin/sh
# Installs and configures nut-client on a host that should shut down when the
# containerized Nutify triggers FSD. Run as root on each monitored host.
#
# FINALDELAY is how many seconds upsmon waits after receiving FSD before running
# SHUTDOWNCMD. On the NanoPi (sbc-01) this should be longer than any other host's
# FINALDELAY so it shuts down last. On other hosts (pve-01, pve-02) 5-30s is fine.
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

if command -v apt-get >/dev/null 2>&1; then
  apt-get update
  apt-get install -y nut-client
else
  echo "This quick script currently supports apt-based hosts only."
  exit 1
fi

mkdir -p /etc/nut
cp -a /etc/nut/nut.conf "/etc/nut/nut.conf.bak.$(date +%s)" 2>/dev/null || true
cp -a /etc/nut/upsmon.conf "/etc/nut/upsmon.conf.bak.$(date +%s)" 2>/dev/null || true

cat > /etc/nut/nut.conf <<EOF
MODE=netclient
EOF

cat > /etc/nut/upsmon.conf <<EOF
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

chmod 640 /etc/nut/upsmon.conf

systemctl enable nut-client
systemctl restart nut-client
systemctl status nut-client --no-pager

echo "NUT client is configured for ${UPS_NAME}@${NUT_SERVER} with FINALDELAY ${NUT_FINAL_DELAY}."
