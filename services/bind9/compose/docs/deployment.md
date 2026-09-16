# Deployment and operations

## VM prerequisites

Use two separate physical hosts and static VM addresses, without selecting a VLAN in this project. A starting allocation per VM is 1-2 vCPUs, 1 GiB RAM, and 4-8 GiB disk. The containers have 256 MiB and 512 MiB limits; the resolver cache is 128 MiB, not its total process memory. Measure actual usage before changing limits.

Use rootful containerd/nerdctl. On Alpine, configure a compatible OCI runtime, cgroup mounts/controllers, and nerdctl's `cgroupfs` manager instead of systemd. Enable containerd with OpenRC. Install BuildKit for native image builds, Bash, and coreutils. The management machine additionally needs envsubst, SSH, tar, OpenSSL, jq, age, and SOPS. Use SSH keys; the deployment script requires a root-capable SSH target and fails rather than requesting credentials interactively.

For Alpine management/testing, typical additional packages are `bash gettext-envsubst openssh-client openssl jq bind-tools iproute2 coreutils`. Obtain age/SOPS through your existing workflow. Do not add all of edge to the VM's repositories simply for nerdctl: explicitly select/pin that package and its compatible dependencies, test the combination, and record installed versions. BuildKit is not needed when deploying a prebuilt registry image.

Check UDP and TCP 53 and 5353 are available on each chosen address. Stop or move a competing VM DNS/mDNS service. Keep time synchronized for DNSSEC and TSIG. Give the VM itself independent bootstrap DNS, such as pfSense, so pulling/building an image does not depend on the DNS containers being healthy.

## Network rules

Apply host firewall rules as well as pfSense rules. Traffic between VMs on the same subnet may never traverse pfSense.

| Source | Destination | Allow |
| --- | --- | --- |
| VLAN 10, 20, 30, 40, 90 | both DNS VM addresses | UDP and TCP 53 |
| both DNS VMs | both DNS VM addresses | UDP and TCP 5353 |
| both DNS VMs | Internet authoritative servers | UDP and TCP 53, return traffic |
| management machine | DNS VMs | TCP 22 |
| VMs during builds/pulls | package mirrors/registries and bootstrap resolver | required HTTPS and DNS |
| VMs | time servers | required NTP |
| future ExternalDNS source addresses | primary DNS VM | TCP 5353; updates/listing require its TSIG key |

Keep 8053/8054 inaccessible to ordinary clients. Statistics ACLs initially allow only loopback and the node itself. No RNDC control channel is enabled. Never forward DNS ports from WAN, and never allow public recursion. Allow TCP DNS, not only UDP: transfers, truncation fallback, and large answers require it.

The subnet ACL is explicit, not all of `10.0.0.0/8`. If pfSense queries from an address outside those ranges, add that exact source. DNS permission does not override inter-VLAN application access rules.

## Images

The supplied image uses a verified amd64/arm64 Alpine manifest and matching pinned BIND packages. The host OS may be Alpine 3.24 even though the container uses 3.23. ISC's checked `9.20` image advertised only amd64, which is why this small Dockerfile is provided.

Default `BUILD_IMAGE=1` builds natively on each VM and uses `tusko-bind:local`. Base/BIND pins do not freeze every transitive APK dependency. For strict repeatability, build/test once per architecture, publish a multi-architecture image to your registry, set `BUILD_IMAGE=0`, and set `BIND_IMAGE` to its immutable index digest. Preserve published images for rollback. A digest/tag is not a promise to receive future security updates: deliberately update pins, review release notes, and test regularly.

Containers start with only NET_BIND_SERVICE, SETUID, and SETGID, then `named -u dns` drops to UID/GID 10001. Configuration, static zones, and secrets are read-only; only data/cache directories are writable. Logs use capped json-file rotation; routine query logging is disabled.

## Deployment

Run the reusable `scripts/deploy.sh` commands in the README from your management machine. SOPS decrypts locally. Only the primary receives the ExternalDNS key; both receive the transfer key. The recursive container receives neither. The management machine's age identity is never copied to the VMs.

Each deployment stages a new `/opt/dns/releases/release.*` directory, builds/pulls the image, validates configuration and primary zone data, prepares permissions and persistent directories, recreates that node's containers, and probes local records before changing `/opt/dns/current`. Do not deploy both nodes concurrently. Initial deployment should be primary first, then secondary. Verify zone serials converge before taking the primary offline.

Deployment is staged, not a multi-node atomic transaction. If post-start probes fail, the current link remains on the previous release, but containers may already use the new files. Inspect logs and explicitly activate the previous release. The script deliberately does not roll back mutable Kubernetes data automatically.

Keep failed/previous releases until verified. They contain plaintext runtime keys and must remain root-protected; retention and secure removal are an operator responsibility. The project has no automatic cleanup that could delete your current directory or persistent data.

## Startup and maintenance

`restart: unless-stopped` controls container exits; Compose is not a boot service. Enable containerd at boot and verify your exact containerd/nerdctl restart behavior with a VM reboot and an intentionally stopped container. Do not assume Docker and nerdctl are identical.

An optional OpenRC reconciliation service is provided at `examples/tusko-dns.openrc`. Install it as `/etc/init.d/tusko-dns`, executable, after the first deployment, then enable it with `rc-update add tusko-dns default`. It uses cached images and `/opt/dns/current` at boot, not builds or Internet pulls. This explicit boot policy starts stopped containers again; during intentional maintenance, stop the service and remove it from the default runlevel. This is distinct from the container's `unless-stopped` behavior.

On a VM, use a stable project name and namespace:

```sh
cd /opt/dns/current
nerdctl --namespace dns compose -p tusko-dns ps
nerdctl --namespace dns compose -p tusko-dns logs --tail 100
```

Health checks record unhealthy status but do not automatically restart a stuck process. Monitor actual DNS answers. A configuration-only restart is possible, but use the deployment script for changed mounts/images and test your edits before restarting.

## Record changes and rollback

Edit the source zone and increment its SOA serial (RFC 1982 ordering; `YYYYMMDDnn` is the current convention). A changed address with an unchanged serial will not reliably reach the secondary. Address changes in `.env` also change NS-host A records: increment the management zone serial. Add PTRs separately; one canonical PTR per address is usually enough. Do not add PTRs for every alias.

To undo static data, restore the previous content with a NEWER serial and redeploy, rather than deploying a lower serial from Git. Validate the new primary and secondary SOA values. To roll back only configuration/image, activate an existing previous release on that VM with `bash /opt/dns/releases/OLD_RELEASE/scripts/activate.sh /opt/dns/releases/OLD_RELEASE`; ensure the old image remains available and compatible with persistent files.

## Backups and acceptance

Back up Git plus encrypted keys and the primary's `/opt/dns/data/auth-lib`. For a consistent dynamic-zone backup, stop only the primary authoritative container, back up its zone and journal together, then start it; the secondary continues reads. Encrypt backups and test restoration with UID/GID 10001 ownership. Resolver caches are disposable, but preserving managed-root-key state avoids unnecessary reinitialization.

Before switching DHCP, run `bash scripts/probe.sh NODE_ADDRESS public` from each VLAN. Check both node SOAs at port 5353 agree; verify unsigned AXFR is rejected, Guest access follows your stated policy, and a non-allowed network is refused. Power off each VM in turn, restart the surviving VM, and verify local/public answers. Reboot both normally. Finally stop both stacks and test public DNS through pfSense while confirming private queries fail instead of leaking to public DNS.
