#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "sysctl ipv6"

ENABLE_IPV6="${ENABLE_IPV6:-y}"
IPV6_FORWARDING="${IPV6_FORWARDING:-n}"

if is_no "$ENABLE_IPV6"; then
    echo "ENABLE_IPV6=n, skipping"
    exit 0
fi

cat > /etc/sysctl.d/99-ipv6.conf << 'EOF'
# written by rpi-os-lite
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
EOF

if [ "$IPV6_FORWARDING" = "prompt" ]; then
    if [ -t 0 ]; then
        read -r -p "enable IPv6 packet forwarding (for routers/gateways)? [y/N] " ans || ans=n
        if is_yes "${ans:-n}"; then
            IPV6_FORWARDING="y"
        else
            IPV6_FORWARDING="n"
        fi
    else
        echo "non-interactive session; defaulting IPV6_FORWARDING to n"
        IPV6_FORWARDING="n"
    fi
fi

if is_yes "$IPV6_FORWARDING"; then
    cat >> /etc/sysctl.d/99-ipv6.conf << 'EOF'
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
EOF
    echo "ipv6 forwarding: enabled"
else
    echo "ipv6 forwarding: disabled"
fi

sysctl --system >/dev/null 2>&1 || true

echo "sysctl: ipv6 enabled"
