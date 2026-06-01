# wireguard_server

Provisions an Alpine Linux WireGuard server with nftables-based peer access controls.

## scope

- installs WireGuard, nftables, and iproute2
- enables IPv4 forwarding
- writes the WireGuard interface config
- writes an nftables policy for SSH, WireGuard ingress, and peer-to-peer tunnel access
- enables the WireGuard and nftables OpenRC services

This role does not generate client configs, configure DNS, or provide internet egress/NAT. It also owns the configured nftables ruleset path, which defaults to `/etc/nftables.nft`.

## access control

The `can_talk_to` list is source-initiated. A peer can start connections only to the CIDRs listed under that peer. Replies for approved connections are allowed by connection tracking, but the reverse peer cannot start a new connection unless its own `can_talk_to` list allows it.

```yaml
wireguard_peers:
  - name: admin-laptop
    ip: "10.44.0.2"
    public_key: "replace-with-admin-laptop-public-key"
    can_talk_to:
      - "10.44.0.0/24"

  - name: restricted-client
    ip: "10.44.0.3"
    public_key: "replace-with-restricted-client-public-key"
    can_talk_to:
      - "10.44.0.2/32"
```

## important variables

- `wireguard_private_key`: server private key. keep this only in ignored inventory or encrypted vars.
- `wireguard_address`: server tunnel address with CIDR, such as `10.44.0.1/24`.
- `wireguard_listen_port`: UDP port for WireGuard.
- `wireguard_ssh_listen_port`: SSH port on the server itself. this can differ from `ansible_port` when SSH is forwarded through NAT.
- `wireguard_ssh_allowed_cidrs`: source CIDRs allowed to reach SSH.
- `wireguard_udp_allowed_cidrs`: source CIDRs allowed to reach the WireGuard UDP port.
- `wireguard_peers`: peer definitions and their source-initiated access rules.
