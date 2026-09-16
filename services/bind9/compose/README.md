# tusko.org internal DNS

Two independent VM stacks, each managed with nerdctl Compose:

| Node | Authoritative BIND | Recursive BIND |
| --- | --- | --- |
| primary | primary zones, UDP/TCP 5353 | client DNS, UDP/TCP 53 |
| secondary | persisted secondary zones, UDP/TCP 5353 | client DNS, UDP/TCP 53 |

Both resolvers can query both authoritative servers. Internet names use direct recursion and DNSSEC validation. Only private zones have validation exceptions. Nothing is publicly exposed or delegated from Cloudflare.

Host networking preserves client source addresses and avoids CNI/NAT dependencies for DNS. The VM addresses and VLAN placement are deliberately unspecified. Port 5353 is unicast authoritative DNS here, not multicast DNS. NS records identify the hosts, but normal DNS delegations cannot specify this port; these are hidden internal authorities reached through explicit forwarding.

## Data ownership

- [zones/](zones/) contains the Git-managed management, DMZ, and five reverse zones.
- [config/static-zones.tsv](config/static-zones.tsv) lists zone names and filenames, separated by whitespace.
- [config/k8s.tusko.org.seed](config/k8s.tusko.org.seed) is a one-time bootstrap, not the live Kubernetes zone.
- Kubernetes records and secondary replicas live under `/opt/dns/data/auth-lib`, never in Git or release directories.
- [config/clients.conf.template](config/clients.conf.template) allows the five requested VLAN networks, both DNS nodes, and loopback. Guests receive the same answers by request; this reveals internal names, not application access.
- `secrets/keys.enc.json` will hold SOPS-encrypted TSIG keys after initialization. Plaintext keys and generated bundles are ignored by Git.

The primary is the only writer. Secondary reads survive primary failure for up to the SOA expiry, currently 14 days since its last successful refresh. New Kubernetes updates require the primary; no automatic writer promotion is attempted.

## Start here

1. Read [docs/deployment.md](docs/deployment.md) and choose two static VM addresses.
2. Copy [.env.example](.env.example) to `.env` and replace both address placeholders. These files use trusted, shell-compatible assignments; scripts source them. Do not put shell commands or untrusted dotenv content in them.
3. Initialize encrypted keys on your management machine:

   ```sh
   bash scripts/secrets.sh init YOUR_PUBLIC_AGE_RECIPIENT
   ```

4. Commit source configuration, zones, and the encrypted key file to your eventual production repository. Do not commit decrypted keys or generated bundles.
5. Create the VMs, install runtime prerequisites, and add the documented firewall rules.
6. Deploy sequentially from the management machine:

   ```sh
   bash scripts/deploy.sh primary root@PRIMARY_VM_ADDRESS
   bash scripts/deploy.sh secondary root@SECONDARY_VM_ADDRESS
   ```

7. Configure pfSense using [docs/pfsense.md](docs/pfsense.md), then run the live probes from every client VLAN before changing DHCP.

For later changes, edit source, increment every affected SOA serial, and rerun the deployment script one node at a time. There is no continuously running deployment controller.

`homelable.dmz.tusko.org` is retained as supplied and aliases `vm-06`. Until a reverse proxy exists, its URL still needs `:3005`. DNS cannot supply that port in an A record.

## Local tests

On an isolated Linux test host with containerd, nerdctl, BuildKit, Bash, envsubst, OpenSSL, jq, iproute2, dig, and nsupdate:

```sh
sudo bash tests/run.sh
```

The test builds the image, validates both configurations, creates four temporary containers in `tusko-dns-validation`, and temporarily assigns `127.0.0.2/32` and `127.0.0.3/32` to loopback if absent. It refuses occupied DNS endpoints, removes its containers and only the addresses it added, and retains ignored test artifacts for inspection. Do not run tests concurrently.

It covers forward/CNAME/PTR records, TCP DNS, client ACL rejection, unsigned AXFR denial, signed transfers, scoped Kubernetes updates, direct public recursion, positive/negative DNSSEC, persisted secondary zones, and either-node outages with cold resolver caches. Use `RUN_PUBLIC_TESTS=0` only for an offline run; that does not certify Internet recursion or DNSSEC.

The native amd64 image and acceptance suite were validated locally. arm64 package availability was checked, but native arm64 execution, Alpine VM reboot recovery, real cross-VLAN firewalls, actual SSH deployments, pfSense fallback, and Kubernetes deployment remain target-environment acceptance tests.

## Operations and extensions

- [docs/deployment.md](docs/deployment.md): prerequisites, ports, deployment, startup, rollback, and backups.
- [docs/pfsense.md](docs/pfsense.md): DHCP, automatic router fallback, private forwarding, and loop avoidance.
- [docs/extensions.md](docs/extensions.md): public-name exceptions, monitoring, encrypted DNS, IPv6, VPN, Kubernetes, and optional DHCP integration.
