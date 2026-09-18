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

tcp_ports="$NFT_SSH_PORT"
for p in $NFT_EXTRA_TCP_PORTS; do
    tcp_ports="$tcp_ports, $p"
done

udp_rules=""
if [ -n "$NFT_EXTRA_UDP_PORTS" ]; then
    udp_ports=""
    for p in $NFT_EXTRA_UDP_PORTS; do
        if [ -z "$udp_ports" ]; then
            udp_ports="$p"
        else
            udp_ports="$udp_ports, $p"
        fi
    done
    udp_rules="udp dport { $udp_ports } accept"
fi

tailscale_input=""
tailscale_forward=""
if is_yes "$NFT_ALLOW_TAILSCALE"; then
    tailscale_input="iifname \"tailscale*\" accept"
fi
if is_yes "$NFT_TAILSCALE_FORWARD"; then
    tailscale_forward="iifname \"tailscale*\" accept; oifname \"tailscale*\" accept;"
fi

cat > /etc/nftables.conf << EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;

        iifname "lo" accept
        ct state established,related accept

        icmp type echo-request accept
        icmpv6 type { echo-request, nd-neighbor-solicit, nd-neighbor-advert, nd-router-advert } accept

        tcp dport { $tcp_ports } accept
        $udp_rules
        $tailscale_input
    }
    chain forward {
        type filter hook forward priority filter; policy drop;
        $tailscale_forward
    }
    chain output {
        type filter hook output priority filter; policy accept;
    }
}
EOF

systemctl enable nftables
systemctl restart nftables
echo "nftables hardened ruleset applied"
