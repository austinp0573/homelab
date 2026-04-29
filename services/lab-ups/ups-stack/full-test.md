# Full UPS Stack Test

Run these from the NanoPi/SBC host, `sbc-01`, unless noted otherwise.

## 1. Pre-Test Checks

Confirm `.env` is set for a real test:

```bash
cd ~/code/services/ups-stack
grep -E '^(FSD_DRY_RUN|FORCE_ON_BATTERY|FORCE_BATTERY_CHARGE|SHUTDOWN_TIME_ON_BATTERY|SHUTDOWN_BATTERY_THRESHOLD|WAKEUP_BATTERY_THRESHOLD|HOST_SHUTDOWN_ENABLED|HOST_SHUTDOWN_DELAY|HOST_SHUTDOWN_COMMAND)=' .env
```

For a real unplug test, expected:

```env
FSD_DRY_RUN=false
FORCE_ON_BATTERY=false
FORCE_BATTERY_CHARGE=
HOST_SHUTDOWN_ENABLED=true
```

Confirm the UPS and UpSnap hosts are visible:

```bash
sudo docker exec nutify upsc lab_apc@localhost
sudo docker exec upsnap ssh -i /app/ssh/id_ed25519 \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile=/app/ssh/known_hosts \
  upsnap-shutdown@10.0.10.21 'hostname'
sudo docker exec upsnap ssh -i /app/ssh/id_ed25519 \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile=/app/ssh/known_hosts \
  upsnap-shutdown@10.0.10.22 'hostname'
```

Clear stale flags from any previous failed test:

```bash
sudo docker exec nut-watcher rm -f /var/run/nut-flags/shutdown-requested.json /var/run/nut-flags/on-battery-since || true
```

Check the host shutdown helper can enter the host namespace without actually shutting down:

```bash
sudo docker exec nut-watcher nsenter -t 1 -m -u -i -n -p -- /bin/true
```

## 2. Rebuild The Stack

For the most realistic reproducibility test, start from a clean runtime state. UpSnap's current image does not expose a working non-interactive superuser CLI, so the first superuser still has to be created in the UpSnap UI before `upsnap-init` can provision devices.

```bash
cd ~/code/services/ups-stack
sudo docker compose down --remove-orphans --volumes --rmi local
sudo rm -rf ./nutify-data ./upsnap-data
sudo docker compose build --no-cache
sudo docker compose up -d --force-recreate
echo "Open UpSnap and create the superuser from UPSNAP_ADMIN_EMAIL / UPSNAP_ADMIN_PASSWORD, then press Enter."
read _
sudo docker compose up --build upsnap-init
sudo docker compose ps
```

If you want to rebuild images without wiping app state, use this lighter path instead:

```bash
cd ~/code/services/ups-stack
sudo docker compose down --remove-orphans
sudo docker compose build --no-cache
sudo docker compose up -d --force-recreate
sudo docker compose up --build upsnap-init
sudo docker compose ps
```

Use the clean-state rebuild when you are testing as much reproducibility as currently possible. Use the lighter path when you only want to test power behavior without resetting UpSnap/Nutify runtime data.

## 3. Start Log Capture

Use one tmux pane per command below. Each command creates/uses the latest log directory automatically, so you can copy/paste them independently.

Pane 1: create the log directory and snapshot config:

```bash
cd ~/code/services/ups-stack
TEST_ID="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="test-logs/${TEST_ID}"
mkdir -p "${LOG_DIR}"
printf '%s\n' "${LOG_DIR}" > /tmp/ups-stack-current-log-dir
cp .env "${LOG_DIR}/env.snapshot"
sudo docker compose config > "${LOG_DIR}/docker-compose.rendered.yml"
echo "Logging to ${LOG_DIR}"
```

Pane 2: all stack logs:

```bash
cd ~/code/services/ups-stack
LOG_DIR="$(cat /tmp/ups-stack-current-log-dir)"
sudo docker compose logs -f --timestamps nutify nut-watcher upsnap upsnap-init upsnap-ssh-init 2>&1 | tee "${LOG_DIR}/compose.log"
```

Pane 3: UPS state every 5 seconds:

```bash
cd ~/code/services/ups-stack
LOG_DIR="$(cat /tmp/ups-stack-current-log-dir)"
while true; do
  date --iso-8601=seconds
  sudo docker exec nutify upsc lab_apc@localhost ups.status || true
  sudo docker exec nutify upsc lab_apc@localhost battery.charge || true
  sudo docker exec nutify upsc lab_apc@localhost battery.runtime || true
  echo
  sleep 5
done 2>&1 | tee "${LOG_DIR}/upsc-watch.log"
```

Pane 4: Docker events:

```bash
cd ~/code/services/ups-stack
LOG_DIR="$(cat /tmp/ups-stack-current-log-dir)"
sudo docker events --filter container=nutify --filter container=nut-watcher --filter container=upsnap 2>&1 | tee "${LOG_DIR}/docker-events.log"
```

Pane 5: host journal:

```bash
cd ~/code/services/ups-stack
LOG_DIR="$(cat /tmp/ups-stack-current-log-dir)"
sudo journalctl -f -o short-iso 2>&1 | tee "${LOG_DIR}/sbc-01-journal.log"
```

## 4. Client-Side Logs

On each Proxmox/NUT client, start:

```bash
journalctl -f -o short-iso -u nut-client -u nut-monitor -u nut-server -u pve-guests 2>&1 | tee "nut-client-test-$(hostname)-$(date +%Y%m%d-%H%M%S).log"
```

Also keep the Proxmox UI open for both configured hosts.

## 5. Run The Unplug Test

1. Confirm all log captures are running.
2. Confirm Nutify UI is reachable.
3. Confirm UpSnap UI is reachable.
4. Unplug AC input to the UPS, not USB.
5. Watch `upsc-watch.log` for `OB`.
6. Watch `compose.log` for `nut-watcher` threshold and FSD messages.
7. Watch Proxmox nodes for NUT client shutdown.
8. Watch `sbc-01` for its own shutdown.
9. Confirm the UPS eventually powers off if that behavior is expected from the NUT/Nutify config.

## 6. Restore Power And Check Wake

1. Plug AC input back into the UPS.
2. Boot `sbc-01` if it does not boot automatically.
3. Start log capture again if needed:

```bash
cd ~/code/services/ups-stack
TEST_ID="$(date +%Y%m%d-%H%M%S)-restore"
LOG_DIR="test-logs/${TEST_ID}"
mkdir -p "${LOG_DIR}"
sudo docker compose logs -f --timestamps nutify nut-watcher upsnap 2>&1 | tee "${LOG_DIR}/restore-compose.log"
```

4. Confirm `nut-watcher` sees the shutdown flag.
5. Confirm it waits for:

```env
WAKEUP_BATTERY_THRESHOLD
```

6. Confirm it calls UpSnap wake endpoints.
7. Confirm Proxmox hosts wake.

## 7. Post-Test Collection

After everything is back online, collect final state:

```bash
cd ~/code/services/ups-stack
TEST_ID="$(date +%Y%m%d-%H%M%S)-post"
LOG_DIR="test-logs/${TEST_ID}"
mkdir -p "${LOG_DIR}"

sudo docker compose ps > "${LOG_DIR}/compose-ps.txt"
sudo docker compose logs --timestamps --no-color nutify nut-watcher upsnap upsnap-init upsnap-ssh-init > "${LOG_DIR}/compose-final.log"
sudo docker exec nutify upsc lab_apc@localhost > "${LOG_DIR}/upsc-final.txt"
sudo docker exec nut-watcher sh -c 'ls -la /var/run/nut-flags && for f in /var/run/nut-flags/*; do echo "--- $f"; cat "$f"; done' > "${LOG_DIR}/nut-flags.txt" 2>&1 || true
sudo journalctl -b -o short-iso > "${LOG_DIR}/sbc-01-current-boot-journal.log"
```

If the previous boot is still available after shutdown/reboot:

```bash
sudo journalctl -b -1 -o short-iso > "${LOG_DIR}/sbc-01-previous-boot-journal.log"
```

## 8. What Success Looks Like

- `upsc-watch.log` shows `ups.status: OB` after AC unplug.
- `nut-watcher` logs show threshold reached.
- `nut-watcher` triggers real FSD because `FSD_DRY_RUN=false`.
- `nut-watcher` waits `HOST_SHUTDOWN_DELAY`, then runs host shutdown through `nsenter`.
- NUT clients shut down cleanly.
- `sbc-01` shuts down cleanly.
- UPS shuts off if configured/expected.
- After AC restore, `nut-watcher` waits for the configured battery threshold.
- UpSnap wake calls are sent.
- Proxmox hosts wake successfully.

## 9. Quick Rollback To Safe Testing

After the test, put the watcher back into safe mode if you are still experimenting:

```env
FSD_DRY_RUN=true
FORCE_ON_BATTERY=false
FORCE_BATTERY_CHARGE=
```

Then apply:

```bash
sudo docker compose up -d
```
