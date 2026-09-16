# pfSense and automatic fallback

## Resolution paths

Advertise the primary VM, secondary VM, and that VLAN's pfSense address in DHCP option 6. Configure static clients equivalently. Do not advertise a public DNS server directly: clients may select it while both local servers are healthy, producing inconsistent private answers.

DNS lists are not guaranteed priority lists. Different clients may use pfSense at any time, and their retry timing differs. This setup provides automatic fallback for clients that retry available servers, not a strict failover guarantee for every OS/application. Test representative clients with both VMs off.

pfSense must therefore give the same private answers in normal operation, but remain independent for public resolution:

```text
client -> BIND resolver -> private BIND authority or Internet authorities
client -> pfSense -> private BIND resolvers or independent Internet resolution
```

Never make BIND globally forward to pfSense while pfSense globally forwards to BIND. Keep the firewall's bootstrap/system DNS independent of the VMs.

## DNS Resolver

Under Services > DNS Resolver, enable Unbound on loopback and the five internal interfaces, not WAN. Allow the five client networks in its access lists. Keep DNSSEC enabled. Leave DNS Query Forwarding unchecked for independent recursion, or configure independent public upstreams if your WAN requires forwarding; do not use the BIND VMs as global upstreams.

After rendering, `build/primary/pfsense-unbound.conf` contains the matching split-DNS fragment. Merge it into Unbound Custom Options and apply. It adds both VM addresses for each of the eight private zones, prevents Internet fallback for those zones, permits private-address responses, and narrows DNSSEC exceptions to those names only. Do not also create GUI Domain Overrides for the same zones. Preserve unrelated Custom Options.

The fragment includes `local-zone: ... transparent` to avoid built-in private reverse-zone handling masking the configured forwarding. Check the generated Unbound configuration on your pfSense version with `unbound-checkconf` before relying on it. Domain Override GUI entries can alternatively use `ADDRESS@PORT`, but the generated fragment makes the two-server configuration explicit and tracks it with the DNS source.

Keep the router's own DHCP registrations/host overrides from conflicting with `mgmt.tusko.org`, `dmz.tusko.org`, or `k8s.tusko.org`. Do not point an override for the entire `tusko.org` domain at BIND. New single-name private exceptions must also appear in pfSense's fragment; rerender and update it with the BIND changes.

Private zones use `forward-first: no`. When both VMs fail, their names fail with SERVFAIL rather than being leaked upstream. Cached local answers can remain until their TTL expires. Public names still resolve through pfSense. Normal public DNS remains DNSSEC validated.

## DHCP and firewall

For each Kea DHCP scope under Services > DHCP Server, explicitly enter primary VM, secondary VM, and the local pfSense interface address as DNS servers. Do not depend on blank-field defaults. Renew leases and inspect the client's actual installed DNS list. IPv6 DNS advertisements are a separate future change.

Allow each VLAN to reach both VM addresses and its router's resolver over UDP/TCP 53. pfSense's outbound private queries must reach the VMs; its independent Internet recursion requires outbound UDP/TCP 53. Keep DNS VM traffic allowed if you later block other clients' direct Internet DNS. Redirecting all client DNS to pfSense would bypass the direct-to-BIND design; do not add that rule blindly.

Routing same-subnet traffic around pfSense means host firewall rules still matter. pfSense fallback is also dependent on the router itself; this does not create router HA or protect against shared switch/WAN failures.

## Acceptance

From every VLAN, query all three advertised endpoints for the same management/DMZ records and reverse records. Query `tusko.org` public records too, to ensure they are not masked. Run `bash scripts/probe.sh ROUTER_VLAN_ADDRESS public` and the same command for each DNS VM.

Turn off one VM, then the other separately. Finally turn both off: query a public name through the router, verify an uncached private query fails, and test normal application/client resolution without explicitly choosing a DNS server. Restore the VMs and clear stale client/router negative caches when necessary. Do not interpret an application cache hit as proof of DNS failover.

Sources: [Netgate domain overrides](https://docs.netgate.com/pfsense/en/latest/services/dns/resolver-domain-overrides.html) and [resolver configuration](https://docs.netgate.com/pfsense/en/latest/services/dns/resolver-config.html).
