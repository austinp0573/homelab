# UPS Stack

Compose-first UPS management stack for the NanoPi:

- `nutify`: a lightly wrapped `dartsteven/nutify:latest-raspberrypi5-arm64` image that renders NUT config from `.env`, initializes Nutify SQLite state, then runs the stock Nutify entrypoint chain. This is the NUT server endpoint that NUT clients connect to.
- `upsnap`: stock UpSnap on host networking so Wake-on-LAN packets reach the physical LAN.
- `nut-watcher`: orchestration helper that polls the NUT server, requests FSD from Nutify/NUT when thresholds are reached, and wakes configured UpSnap targets after AC power returns.

## First NanoPi Run

```bash
cd services/ups-stack
cp .env.example .env
editor .env
docker compose build
docker compose up
```

Keep the first run in the foreground so you can watch for:

- `[ups-stack] Rendering NUT configuration...`
- `[db-init] Created /app/nutify/instance/nutify.db.sqlite`
- Nutify startup logs showing NUT services are healthy.
- `[nut-watcher] Starting threshold monitor`

Nutify should be available on `http://<nanopi-ip>:5050`. UpSnap should be available on `http://<nanopi-ip>:8090`.

## Runtime State

Generated runtime data is intentionally ignored by git:

- `nutify-data/`: rendered NUT configs, Nutify SQLite DB, token, logs, SSL files.
- Docker volume `upsnap-data`: UpSnap PocketBase state.
- `upsnap-data/ssh/`: UpSnap SSH private key and `known_hosts` generated from `.env`.
- Docker volume `nut-flags`: watcher shutdown/wake flags.

The current `nutify-working/` directory is a captured working bind mount used as a reference. It should not be committed because it contains runtime database, token, logs, and plaintext NUT credentials.

## Threshold Behavior

`nut-watcher` is not a NUT server and no clients connect to it. NUT clients should point at the NanoPi's Nutify/NUT service on port `3493`.

`nut-watcher` polls the Nutify/NUT server every `POLL_INTERVAL` seconds.

When the UPS reports `OB`, it starts a persistent on-battery timer. It asks Nutify/NUT to enter FSD when either condition becomes true:

- `battery.charge <= SHUTDOWN_BATTERY_THRESHOLD`
- seconds on battery are `>= SHUTDOWN_TIME_ON_BATTERY`

Before requesting FSD, it writes `shutdown-requested.json` into the shared `nut-flags` volume. The NUT server then exposes FSD to its clients, and the clients shut themselves down according to their own NUT client configuration. On a later boot after AC restore, the watcher waits until the UPS reports `OL` and `battery.charge >= WAKEUP_BATTERY_THRESHOLD`, then calls UpSnap wake endpoints and clears the flag.

Set `FSD_DRY_RUN=true` while testing threshold behavior if you do not want the watcher to run `upsmon -c fsd`.

To test threshold behavior without unplugging the UPS, set dry-run force values:

```env
FSD_DRY_RUN=true
FORCE_ON_BATTERY=true
SHUTDOWN_BATTERY_THRESHOLD=101
```

Restart `nut-watcher`; it will treat the current poll as on battery and should write the shutdown flag without running real FSD. Forced test values are rejected unless `FSD_DRY_RUN=true`.

## UpSnap Targets

UpSnap wake calls use its PocketBase API. Create the UpSnap superuser in the UI with:

```env
UPSNAP_ADMIN_EMAIL=...
UPSNAP_ADMIN_PASSWORD=...
```

### SSH Shutdown Key

UpSnap runs shutdown commands inside the UpSnap container. The stock image already includes `ssh`; this stack mounts `/app/ssh` and writes a private key from `.env`.

Generate a dedicated key:

```bash
ssh-keygen -t ed25519 -f ./upsnap_shutdown_key -C upsnap-shutdown
```

Put the private key into `.env` as base64:

```bash
UPSNAP_SSH_PRIVATE_KEY_B64="$(base64 -w0 ./upsnap_shutdown_key)"
```

The matching public key, `upsnap_shutdown_key.pub`, must be installed on each target host for the user configured by `UPSNAP_SSH_USER`. Later Ansible should own that host-side setup.

For the current manual Proxmox setup, run `upsnap-setup.sh` on each target as root. It creates `upsnap-shutdown`, installs the public key, installs `sudo` if needed, and allows only:

```bash
sudo /usr/bin/systemctl poweroff
```

### Device Provisioning

Define UpSnap devices in `.env` with `UPSNAP_HOSTS_JSON`. Keep it valid JSON on one line:

```env
UPSNAP_HOSTS_JSON=[{"name":"pve1","ip":"192.168.1.10","mac":"aa:bb:cc:dd:ee:ff","netmask":"255.255.255.0","description":"Primary Proxmox host","shutdown_user":"upsnap-shutdown","shutdown_command":"sudo /sbin/shutdown -h now","shutdown_timeout":300}]
```

The provisioner stores this as a full SSH command in UpSnap:

```bash
ssh -i /app/ssh/id_ed25519 ... 'upsnap-shutdown@{{ DEVICE_IP }}' 'sudo /sbin/shutdown -h now'
```

Provision or update devices:

```bash
docker compose up -d upsnap
docker compose up --build upsnap-init
```

After the UpSnap superuser exists, `upsnap-init` matches existing devices by MAC first, then name. It prints the resolved IDs when it succeeds.

If you change `UPSNAP_SSH_PRIVATE_KEY_B64`, rewrite the mounted key:

```bash
docker compose up --force-recreate upsnap-ssh-init
```

For watcher wake targets, `nut-watcher` now reads `UPSNAP_HOSTS_JSON` and resolves those hosts by MAC through the UpSnap API. You can leave these manual wake target fields empty unless you need to add extra devices or pin an UpSnap record ID:

```env
UPSNAP_DEVICE_IDS=abc123,def456
WAKE_MAC_ADDRESSES=aa:bb:cc:dd:ee:ff
```

If a host object includes `"wake_after_restore": false`, the watcher will skip that host during the restore wake sequence. If a host object includes `"upsnap_id": "..."`, the watcher uses that ID directly instead of resolving by MAC.

### Container-Side Shutdown Tests

First test SSH with a harmless command:

```bash
docker exec upsnap ssh -i /app/ssh/id_ed25519 \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile=/app/ssh/known_hosts \
  upsnap-shutdown@192.168.1.10 'hostname'
```

Then test the UpSnap shutdown command from the UI or API. If UpSnap logs `sudo: command not found`, install `sudo` on the Proxmox host and rerun `upsnap-setup.sh`.

This direct `systemctl poweroff` path is the current working container test. Later, Ansible should replace it with a narrower Proxmox-safe script that explicitly manages guest shutdown timing before powering off.

## NUT Clients

Each client that should shut down during FSD needs a NUT secondary monitor pointed at the NanoPi:

```conf
MONITOR lab_apc@<nanopi-ip> 1 monuser <NUT_MON_PASSWORD> slave
```

This stack preserves the older `master`/`slave` syntax used by the working Nutify-generated config.

## Validation Commands

From a workstation with NUT tools:

```bash
upsc lab_apc@<nanopi-ip>
```

From the NanoPi:

```bash
cd services/ups-stack
docker compose logs -f nutify nut-watcher
docker exec nutify upsc lab_apc@localhost
docker exec nutify upsmon -c fsd
```

Run the final `upsmon -c fsd` command only when you are ready to test the real shutdown cascade.
