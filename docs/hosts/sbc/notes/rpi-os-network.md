# rpi os lite network configuration

```bash
sudo nmcli connection modify "netplan-eth0" \
  ipv4.method manual \
  ipv4.addresses 192.168.1.50/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "1.1.1.1, 8.8.8.8"
```

3. Verify the assigned configuration with `ip addr show eth0`.