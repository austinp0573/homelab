# Extensions

## Specific public-name exceptions

Do not make BIND authoritative for all of `tusko.org`. For an internal answer at `service.tusko.org`, add this entry to `config/static-zones.tsv`:

```text
service.tusko.org service.tusko.org.zone
```

Create `zones/service.tusko.org.zone` with:

```dns
$ORIGIN service.tusko.org.
$TTL 300
@ IN SOA dns-primary.mgmt.tusko.org. hostmaster.tusko.org. (2026101201 300 300 1209600 300)
@ IN NS dns-primary.mgmt.tusko.org.
@ IN NS dns-secondary.mgmt.tusko.org.
@ IN A 10.0.90.12
```

Use a current serial, render and validate, deploy the secondary zone declaration before the primary, then wait for transfer. The renderer adds replication, forwarding, and the exact validation exception. Refresh pfSense's generated fragment too.

This is a small authoritative zone, not an A-only overlay: it also owns names beneath `service.tusko.org`, and absent AAAA/TXT/MX/CAA types return local NODATA rather than falling through to Cloudflare. Mirror any public records needed internally. A CNAME cannot coexist with SOA/NS at this zone's apex; choose an A/AAAA override or explicitly design an RPZ override if an apex CNAME is required. Test public `tusko.org` and unrelated public names afterward.

## Monitoring

Both BIND instances already expose restricted statistics on the VM address: resolver HTTP 8053 and authority HTTP 8054. From that VM, inspect `/json/v1/server`, `/json/v1/zones`, or `/xml/v3/server`. These are BIND statistics, not Prometheus metrics. Normal query logging is disabled; container stdout/stderr is rotated at 10 MiB with three files per container.

For Prometheus/Grafana, add two instances of [prometheus-community/bind_exporter](https://github.com/prometheus-community/bind_exporter) per VM, each configured with the appropriate `--bind.stats-url=http://NODE_ADDRESS:8053/` or `:8054/` and distinct `--web.listen-address` ports. Run them on the VM/host network or add their actual source addresses to the statistics ACL. Pin their image versions/digests and expose their scrape ports only to your monitoring network. Do not publish the native statistics channels broadly.

Monitor DNS answers from outside the VM, using Prometheus blackbox DNS probes or an equivalent: UDP/TCP resolution of a management name, DMZ name, reverse record, and public signed name through EACH resolver and pfSense. Track response latency, SERVFAIL rates, timeout rates, validation failures, cache/memory pressure, zone-transfer failures, SOA serial divergence, secondary refresh age/expiry, container health/restarts, and disk/log usage. Alert well before the 14-day secondary expiry. Separate writer availability from read availability for ExternalDNS.

Send bounded operational logs to your eventual log platform. Enable query logging or dnstap only deliberately, with retention/access controls: queries disclose browsing and internal-service activity. Health checks alone neither prove WAN resolution nor restart a hung server.

## Encrypted client DNS

Baseline DNS is UDP/TCP 53. DNSSEC authenticates signed public data; it does not encrypt traffic. TSIG authenticates transfers and updates; it also does not encrypt them.

BIND can serve DoT and DoH without a proxy container. Obtain CA-trusted certificates for the resolver hostnames using Cloudflare DNS-01 or your internal PKI. Keep private keys SOPS-encrypted at rest, deploy them read-only with permissions allowing UID/GID 10001, and extend the deployment script to distribute/rotate those certificate files. Never bake private keys into an image.

For DoT, add this top-level block to the resolver template:

```bind
tls client_dns {
    key-file "/run/tls/privkey.pem";
    cert-file "/run/tls/fullchain.pem";
    protocols { TLSv1.2; TLSv1.3; };
};
```

Add this listener INSIDE the existing options block:

```bind
listen-on port 853 tls client_dns { ${NODE_IPV4}; };
```

Add a read-only TLS directory mount ONLY to the recursive service and permit client TCP 853. For DoH, define a top-level `http client_doh { endpoints { "/dns-query"; }; };` and add `listen-on port 443 tls client_dns http client_doh { ${NODE_IPV4}; };` to options. Reserve port 443 on the DNS VMs, or explicitly choose another supported client endpoint. Apply the existing client ACLs and firewall restrictions.

Validate with the exact image, recreate/reload after certificate renewals, and test hostname verification, trusted chains, expiry alerts, both endpoints, and failover. DHCP option 6 does not automatically enable DoT/DoH; configure supported clients/OS policies separately and account for browser public-DoH bypasses. pfSense's third endpoint must also have a valid configured certificate for clients expecting encrypted fallback. Keep ordinary DNS for unsupported clients unless intentionally replacing it.

Full Internet recursion remains mostly unencrypted upstream. If encrypted upstream transport is required, use verified DoT forwarding to a trusted upstream instead of claiming all authoritative servers support encryption. Retain the private forward-only zones. For encrypted inter-VM transfers, use a protected network/WireGuard or separately configure authenticated TLS zone transfers with certificates plus TSIG.

Cloudflare's public DNSSEC settings need not change. Cloudflare DNS-01 proves public domain control; local split zones may hide those TXT records from local preflight checks. Choose an ACME client that can check public authoritative DNS, or delegate an appropriate challenge namespace. Keep Cloudflare API tokens narrowly scoped and SOPS-managed.

## Kubernetes

Keep these VMs outside Kubernetes: the cluster should not be required to recover the DNS it needs to start. CoreDNS continues to own `cluster.local`; `k8s.tusko.org` contains LAN-facing application names, not the cluster's service-discovery zone.

Configure the cluster's CoreDNS default forwarder with the two VM addresses, for example `forward . PRIMARY_IPV4 SECONDARY_IPV4`. Preserve the Kubernetes plugin and existing CoreDNS defaults. Explicit private-zone forward blocks are another option if public queries should follow a different path. Avoid a loop where BIND forwards back to CoreDNS for these same zones.

Determine whether CoreDNS/ExternalDNS traffic is source-NATed to node IPs or retains pod IPs. Add only the actual permitted node/pod CIDRs to BIND query ACLs and firewalls; do not grant all RFC1918 networks. Use routable ingress/LoadBalancer addresses, not cluster-only Service CIDRs, in external records.

[examples/externaldns-values.example.yaml](../examples/externaldns-values.example.yaml) targets only the primary on TCP 5353 and the `k8s.tusko.org` zone. Replace its primary address and use a pinned, compatible ExternalDNS Helm chart. It uses a TXT registry and prefix to avoid CNAME/TXT collisions, a stable per-cluster owner ID, and starts with `upsert-only`. Review a dry run before enabling `sync` deletion. Do not enable PTR generation for the static reverse zones with this key.

Create the `externaldns-rfc2136` Kubernetes Secret, in the ExternalDNS namespace, containing `tsig-secret` from the decrypted `externaldns` value in the SOPS JSON. Manage that Secret through your SOPS-enabled production GitOps workflow; never commit its plaintext. The transfer key is not a Kubernetes credential. Install the values through your existing Helm deployment workflow; the chart supplies RBAC.

No Git deployment overwrites the live Kubernetes zone. Only its empty seed and update policy are tracked. Back up the primary zone/journal and deploy at most one writer/controller for this ownership scope. Reads survive primary failure, but updates pause until it returns. Source: [ExternalDNS RFC2136 guide](https://kubernetes-sigs.github.io/external-dns/latest/docs/tutorials/rfc2136/).

## IPv6 and remote clients

IPv4-only transport is explicit: image arguments include `-4`, and templates disable IPv6 listeners and query sources. AAAA queries still work; transport and record types are different.

When adding IPv6, assign stable VM addresses, extend the renderer with validated IPv6 parameters, add AAAA records and appropriate `ip6.arpa` zones, allow exact client IPv6 prefixes, configure IPv6 listeners/forwarder addresses and transfer/notify sources, remove `-4` and `query-source-v6 none`, and add matching firewall/DHCPv6/RA settings. Do not blindly use `listen-on-v6 { any; };` without ACLs. Retest public DNSSEC and both-node failure over both transports.

For WireGuard/Tailscale later, add the actual VPN or routed-source prefixes and firewall rules. Advertise both resolvers through the VPN's split-DNS settings for `mgmt`, `dmz`, and `k8s`; include reverse domains if needed. Do not expose port 53 publicly. Remote sites may need independent fallback and must not create forwarding loops.

## Optional DHCP integration

Do not enable DDNS into the Git-managed zones: BIND would rewrite their files/journals and create competing writers. A later Kea integration should use a separate dynamic zone such as `dhcp.tusko.org`, its own tightly scoped key, persistent primary storage, and secondary replication. Verify the actual pfSense/Kea version supports the desired external DDNS/D2 configuration; native pfSense lease registration is not equivalent to BIND DDNS.

Reverse ownership needs a separate design because the existing five reverse zones are static. Delegate a suitable reverse range or deliberately migrate a reverse zone to dynamic management; do not let DHCP and Git update the same file. Add forwarding/DNSSEC handling and backups for the new namespace. Leave this optional until there is a concrete need.
