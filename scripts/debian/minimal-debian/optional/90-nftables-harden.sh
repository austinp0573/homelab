#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "nftables harden"

NFT_SSH_PORT="${NFT_SSH_PORT:-22}"
NFT_EXTRA_TCP_PORTS="${NFT_EXTRA_TCP_PORTS:-}"
NFT_EXTRA_UDP_PORTS="${NFT_EXTRA_UDP_PORTS:-}"
NFT_ALLOW_TAILSCALE="${NFT_ALLOW_TAILSCALE:-n}"
NFT_TAILSCALE_FORWARD="${NFT_TAILSCALE_FORWARD:-n}"

apt_install nftables

valid_port() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) [ "$1" -ge 1 ] && [ "$1" -le 65535 ] ;;
    esac
}

if ! valid_port "$NFT_SSH_PORT"; then
    echo "invalid NFT_SSH_PORT: $NFT_SSH_PORT"
    exit 1
fi

extra_rules=""
for p in $NFT_EXTRA_TCP_PORTS; do
    valid_port "$p" || {
        echo "invalid TCP port: $p"
        exit 1
    }
    extra_rules="${extra_rules}
        tcp dport $p accept"
done

for p in $NFT_EXTRA_UDP_PORTS; do
    valid_port "$p" || {
        echo "invalid UDP port: $p"
        exit 1
    }
    extra_rules="${extra_rules}
        udp dport $p accept"
done

tailscale_input=""
tailscale_forward=""
if is_yes "$NFT_ALLOW_TAILSCALE"; then
    tailscale_input="        iifname \"tailscale0\" accept
        udp dport 41641 accept"
fi
if is_yes "$NFT_TAILSCALE_FORWARD"; then
    tailscale_forward="        iifname \"tailscale0\" accept
        oifname \"tailscale0\" accept"
fi

cat > /etc/nftables.conf << EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;

        ct state established,related accept
        iif lo accept
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept

        tcp dport $NFT_SSH_PORT accept
$extra_rules
$tailscale_input
    }
    chain forward {
        type filter hook forward priority filter; policy drop;
        ct state established,related accept
$tailscale_forward
    }
    chain output {
        type filter hook output priority filter; policy accept;
    }
}
EOF

systemctl enable nftables
systemctl restart nftables
echo "nftables hardened (ssh $NFT_SSH_PORT)"
