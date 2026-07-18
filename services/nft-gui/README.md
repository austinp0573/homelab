# nft-gui

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### nft-gui

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | <1% | ~5-15 MB | tiny static nginx image | idle |
| expected | 1-3% | ~10-30 MB | no server-side ruleset storage | serving the SPA |
| high | 0.1 core | ~64 MB | still tiny | many concurrent page loads |

State lives in the browser; the container is just static files.

Small browser UI for building nftables config files.

It does not inspect, validate against, or apply the host firewall. It only serves a static page and keeps the working ruleset in browser storage.

## run

```bash
cd services/nft-gui
cp .env.example .env
./scripts/up.sh
```

Open `http://127.0.0.1:8787`, unless the bind address or port was changed in `.env`.

```bash
./scripts/smoke.sh
./scripts/down.sh
```

The scripts use `nerdctl compose` when it is present, otherwise `docker compose`.

## supported config pieces

- inet, ip, ip6, bridge, and netdev tables
- filter, nat, and route chains with family-aware hook choices
- netdev base chains require a device name
- regular chains, jump, goto, policies, counters, logging, and rate limits
- address and port sets, including interval sets and set timeouts
- source and destination address or port matches
- connection tracking state, status, direction, marks, and optional ftp or tftp helper objects
- typed IPv4 or IPv6 maps for address to verdict and address to packet-mark lookups
- common filter, forwarding, and NAT rules

The form intentionally has no raw nft expression input. If a rule needs syntax this UI does not model, finish the exported config by hand.

## checks and export

The preview shows a syntax line and errors for every rule. Export is still possible when errors exist after confirmation. Invalid rules, chains, tables, and objects are emitted as comments or skipped so the remaining output can still be checked.

Always check the result on the target host before applying it:

```bash
nft --check --file nftables.conf
```

Keep console or out-of-band access while changing a remote firewall.

Forward rules require IP forwarding outside of nftables. The generated config adds comments with the relevant `sysctl` command for ip and ip6 tables. It does not change host sysctls.

Connection tracking helpers depend on the host kernel having the matching helper available.

## storage and import

Use JSON export for backups or moving the draft to another browser. JSON import accepts only the fields used by the UI and has a 1 MiB input limit.

Older local rulesets are migrated to the current format. Raw expressions from older drafts are discarded because they are no longer part of the supported model.


&nbsp;

**466f724a616e6574**
