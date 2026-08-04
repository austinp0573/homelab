#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

# defaults (override in .env)
HEADSCALE_VERSION="${HEADSCALE_VERSION:-0.29.2}"
HEADSCALE_ARCH="${HEADSCALE_ARCH:-${ARCH:-amd64}}"
HEADSCALE_SHA256="${HEADSCALE_SHA256:-}"
HEADSCALE_URL="${HEADSCALE_URL:-}"
HEADSCALE_SERVER_URL="${HEADSCALE_SERVER_URL:-}"
HEADSCALE_MAGICDNS_BASE="${HEADSCALE_MAGICDNS_BASE:-}"
HEADSCALE_MAGICDNS_ENABLED="${HEADSCALE_MAGICDNS_ENABLED:-true}"
HEADSCALE_LISTEN_ADDR="${HEADSCALE_LISTEN_ADDR:-127.0.0.1:8080}"

echo "headscale $HEADSCALE_VERSION"

apt_install curl ca-certificates

if [ -z "$HEADSCALE_SHA256" ]; then
    echo "HEADSCALE_SHA256 must be set"
    exit 1
fi

bin_url="https://github.com/juanfont/headscale/releases/download/v${HEADSCALE_VERSION}/headscale_${HEADSCALE_VERSION}_linux_${HEADSCALE_ARCH}"
bin_tmp="/tmp/headscale_${HEADSCALE_VERSION}_linux_${HEADSCALE_ARCH}"
echo "downloading $bin_url"
curl -fsSL -o "$bin_tmp" "$bin_url"
printf '%s  %s\n' "$HEADSCALE_SHA256" "$bin_tmp" | sha256sum -c -
install -m 755 "$bin_tmp" /usr/local/bin/headscale
rm -f "$bin_tmp"

ensure_dir /etc/headscale
ensure_dir /var/lib/headscale
ensure_dir /var/run/headscale

if ! getent passwd headscale >/dev/null; then
    useradd --system --home /var/lib/headscale --shell /usr/sbin/nologin headscale
fi
chown -R headscale:headscale /var/lib/headscale
chown -R headscale:headscale /var/run/headscale

# server_url: explicit SERVER_URL, else HEADSCALE_URL, else placeholder
server_url="$HEADSCALE_SERVER_URL"
if [ -z "$server_url" ]; then
    server_url="$HEADSCALE_URL"
fi
if [ -z "$server_url" ]; then
    server_url="http://127.0.0.1:8080"
fi

magic_base="$HEADSCALE_MAGICDNS_BASE"
if [ -z "$magic_base" ]; then
    magic_base="tailnet.example.com"
fi

if [ "$HEADSCALE_MAGICDNS_ENABLED" != "true" ] &&
   [ "$HEADSCALE_MAGICDNS_ENABLED" != "false" ]; then
    echo "HEADSCALE_MAGICDNS_ENABLED must be true or false"
    exit 1
fi

if [ ! -f /etc/headscale/acl.hujson ]; then
    cat > /etc/headscale/acl.hujson << 'EOF'
// basic acl skeleton — edit to taste
// https://tailscale.com/docs/features/access-control/acls
{
  // groups: {
  //   "group:admins": ["user1@"],
  // },

  "acls": [
    // allow all members to talk to each other (open tailnet)
    {
      "action": "accept",
      "src": ["*"],
      "dst": ["*:*"]
    }
  ]

  // tags: {
  //   "tag:server": ["user1@"],
  // },
}
EOF
    echo "wrote /etc/headscale/acl.hujson"
fi

if [ ! -f /etc/headscale/config.yaml ]; then
    cat > /etc/headscale/config.yaml << EOF
# headscale config skeleton — edit before production use
# docs: https://headscale.net/

server_url: ${server_url}
listen_addr: ${HEADSCALE_LISTEN_ADDR}
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 127.0.0.1:50443
grpc_allow_insecure: false

# set to your haproxy/proxy cidrs if headscale sits behind one
trusted_proxies: []

noise:
  private_key_path: /var/lib/headscale/noise_private.key

prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
  allocation: sequential

derp:
  server:
    enabled: false
    region_id: 999
    region_code: headscale
    region_name: Headscale Embedded DERP
    stun_listen_addr: 0.0.0.0:3478
    private_key_path: /var/lib/headscale/derp_server_private.key
    automatically_add_embedded_derp_region: true
    # ipv4: 203.0.113.10
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  paths: []
  auto_update_enabled: true
  update_frequency: 3h

database:
  type: sqlite
  sqlite:
    path: /var/lib/headscale/db.sqlite
    write_ahead_log: true

# tls usually terminated at haproxy; leave empty when proxying
tls_cert_path: ""
tls_key_path: ""

log:
  level: info
  format: text

policy:
  mode: file
  path: /etc/headscale/acl.hujson

dns:
  magic_dns: ${HEADSCALE_MAGICDNS_ENABLED}
  # must differ from the server_url hostname
  base_domain: ${magic_base}
  override_local_dns: true
  nameservers:
    global:
      - 1.1.1.1
      - 1.0.0.1

unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"

logtail:
  enabled: false

taildrop:
  enabled: true
EOF
    chown root:headscale /etc/headscale/config.yaml
    chmod 640 /etc/headscale/config.yaml
    echo "wrote /etc/headscale/config.yaml"
else
    echo "config exists, not overwriting /etc/headscale/config.yaml"
fi

chown root:headscale /etc/headscale/acl.hujson
chmod 640 /etc/headscale/acl.hujson

cat > /etc/systemd/system/headscale.service << 'EOF'
[Unit]
Description=headscale
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=headscale
Group=headscale
ExecStart=/usr/local/bin/headscale serve
Restart=on-failure
RestartSec=5
RuntimeDirectory=headscale
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now headscale
echo "headscale enabled (server_url=$server_url)"
echo "next: headscale users create <name>  then create preauth keys for nodes"
