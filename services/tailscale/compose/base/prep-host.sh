#!/bin/sh
# Prep host networking for network_mode: host Tailscale
set -e

# Enable IPv4 & IPv6 packet forwarding if not already enabled
if [ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" != "1" ] || \
   [ "$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null)" != "1" ]; then
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null
  printf "net.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1\n" > /etc/sysctl.d/99-tailscale.conf
fi

# Ensure TUN device node exists
if [ ! -c /dev/net/tun ]; then
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
  chmod 0666 /dev/net/tun
fi
