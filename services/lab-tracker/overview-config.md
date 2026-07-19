# lab-tracker config

local inventory UI. no auth — keep on loopback or behind a gate.

## compose `.env`

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `lab-tracker` | also local image `${name}:local` from the build. changing project name changes the image tag expectation — rebuild awareness required. keep stable once you’ve scripted `up.sh`. Renaming mid-flight orphans volumes unless you migrate them on purpose. |
| `CONTAINER_NAME` | `lab-tracker` | fixed container name for logs and proxy backends. no auth in-app — whoever can hit the port can edit inventory. collisions fail `up`. Proxy backends and smoke scripts often hardcode this string. |
| `RESTART_POLICY` | `unless-stopped` | UI comes back after reboot with the same `./data`. inventory lives on disk, not in the image — don’t confuse rebuild with data loss. stop when exposing mistakenly. Use an explicit stop for maintenance; otherwise expect it back after reboot. |
| `HOST_BIND` | `127.0.0.1` | loopback default because there is **no auth**. `0.0.0.0` is only OK behind a real gate or air-gapped LAN you trust. this is the highest-priority footgun in this stack. Loopback plus an edge proxy is the usual safe exposure model. |
| `HOST_PORT` | `8791` | → container `8080`. change on conflict and update any HAProxy snippet. smoke scripts often assume 8791 on localhost. Change the left-side publish and update every caller in the same commit. |
| `DATA_DIR` | `/data` (in-container) | host `./data` mounted there — `inventory.yml` lives on the host side. wipe host `./data` and the lab inventory is gone. back up that yaml if it’s your source of truth. Wipe equals data loss unless you have a restore you have actually rehearsed. |

## inventory YAML (`data/inventory.yml`)

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `version` | `1` | schema version for the inventory file. bump only when the app expects a new schema — don’t invent `2` casually. mismatched version may refuse to load or ignore fields. Pin once the stack is boring; floating tags are for active testing only. |
| `custom_fields[]` | `[]` | `{key, label, category}` definitions for extra columns. keys must stay stable once assets use them — renaming keys orphans values. empty is fine until you need structured extras. Keys must stay stable once assets populate them or values go orphan. |
| `assets[]` | `[]` | inventory entries array; the whole product. edit via UI preferentially to avoid YAML merge pain. empty array is a valid fresh start. Prefer the UI for edits when you can; raw YAML merges get ugly fast. |
| asset `id` / `name` / `type` / `status` | status default `active` | `id` is the stable reference for relations; `name` must be unique case-insensitive. types: physical, vm, vps, lxc, nas, switch, ap, ups, pi, gpu, service, network, backup_job, other. statuses: draft, planned, active, maintenance, inactive, retired — wrong status strings may fail validation. Ids are the relation graph keys — rename names freely, ids carefully. |
| relation lists | `[]` | `parents`, `powered_by`, `backup_jobs`, `depends_on`, `backed_up_by`, `fronted_by`, `monitored_by` — must be valid asset ids. dangling ids break the graph UI or saves. use relations for real topology, not notes spam. Dangling ids break the graph; validate ids exist before saving. |
| optional string fields | omitted if empty | notes, os, hostname, role, location, cpu, ram, disks, gpu, serial, asset_tag, purchase_date, warranty, ssh_user, ssh_port, mgmt_url, tailscale, wireguard, secrets, provider, region, cost, hypervisor, vmid, storage_pool, bridge, model, boot, dns_names. omit empties to keep YAML diffable. `secrets` is plaintext in yaml — don’t put real vault material here. Omit empties to keep diffs readable; never put vault material in secrets fields. |
| `tags` | `[]` | freeform tags for filtering; keep a small controlled vocabulary or they become useless. duplicates/noise slow scanning. not a substitute for typed relations. A small controlled vocabulary beats an exploding tag soup. |
| `interfaces[]` | optional | name / mac / ips / network / role per NIC. helpful for switch/AP/vms; skip for abstract services. bad MACs/IPs are documentation bugs, not validated against the wire. Documentation only — nothing here is validated against the live wire. |

optimistic concurrency via content hash. anything in `secrets` fields is plaintext in yaml. names unique case-insensitive.
