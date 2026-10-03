# nut-tool

`nut-tool` is a Linux UPS orchestration daemon written in Rust. It talks directly
to a Network UPS Tools (`upsd`) server, latches a shutdown when configured policy
is reached, shuts configured hosts down over SSH with bounded retries, waits for
utility power to be stably restored and the UPS battery to recharge, then sends
Wake-on-LAN packets in configurable priority order.

The intended release artifact is a statically linked Linux/musl ELF. The runtime
does not execute `upsc`, `ssh`, `wakeonlan`, a shell, Python, or other helper
programs.

## State machine

Typical cycle:

```
UNKNOWN -> ONLINE -> ON_BATTERY -> SHUTTING_DOWN -> WAITING_FOR_MAINS
                                                    |
                                                    v
                                               RECHARGING
                                                    |
                                                    v
                                                 WAKING
                                                    |
                                                    v
                                                  ONLINE
```

Shutdown is latched: once `SHUTTING_DOWN` begins, utility recovery does not cancel
remaining shutdown attempts. Wake is allowed only after `OL` remains continuously
stable for the configured period and `battery.charge` reaches the configured
wake threshold.

Persistent state is atomically stored so a process restart does not repeat already
successful shutdown/WOL work or reset an active outage timer.

## 1. Build

### Recommended: build with nerdctl

On an amd64 host this builds an amd64 musl binary; on arm64 it builds arm64.

```bash
cd nut-tool
nerdctl build -f deploy/build/Containerfile -t local/nut-tool:latest .
```

The final image is `scratch` and contains only `/nut-tool`.

To extract the ELF for systemd/bare-metal deployment:

```bash
cid="$(nerdctl create local/nut-tool:latest)"
nerdctl cp "$cid:/nut-tool" ./nut-tool
nerdctl rm "$cid"
chmod 0755 ./nut-tool
```

Verify it:

```bash
file ./nut-tool
ldd ./nut-tool || true
readelf -l ./nut-tool | grep -i interpreter || true
readelf -d ./nut-tool | grep NEEDED || true
```

The build Containerfile itself fails if the result contains a requested ELF
interpreter or `DT_NEEDED` entries.

### Native Rust build on Debian

Install the Rust toolchain and native build prerequisites, then for an amd64
controller:

```bash
sudo apt update
sudo apt install -y rustup build-essential musl-tools cmake perl pkg-config
rustup default stable

rustup target add x86_64-unknown-linux-musl
CC_x86_64_unknown_linux_musl=musl-gcc \
  cargo build --release --target x86_64-unknown-linux-musl

cargo test
```

The binary is:

```text
target/x86_64-unknown-linux-musl/release/nut-tool
```

On a native arm64 build machine use `aarch64-unknown-linux-musl` instead. Building
arm64 from an amd64 host additionally requires a suitable arm64-musl linker or a
containerized cross-build environment.

After the first successful Cargo build, commit the generated `Cargo.lock` file.

## 2. Generate the dedicated shutdown SSH key

On the controller/build workstation:

```bash
ssh-keygen -t ed25519 -N '' -f ./id_ed25519 -C 'nut-tool shutdown-only'
chmod 0600 ./id_ed25519
```

The key intentionally has no passphrase because an unattended daemon must use it.
Its authority is restricted on every target with an OpenSSH forced command and an
exact sudoers rule.

Do not compile the private key into the binary and do not commit it to Git.

## 3. Install each remote shutdown target

Copy `deploy/remote/` and `id_ed25519.pub` to each target. Install `sudo` first if
it is absent:

Debian/Ubuntu/Proxmox:

```bash
sudo apt update
sudo apt install -y sudo
sudo ./deploy/remote/install-target.sh ./id_ed25519.pub
```

Alpine:

```bash
sudo apk add sudo
sudo ./deploy/remote/install-target.sh ./id_ed25519.pub
```

The installer creates `ups-shutdown`, installs a root-owned forced-command gate,
installs one exact sudoers rule, and selects either the systemd or Alpine shutdown
helper.

The resulting authorized key is equivalent to:

```text
restrict,command="/usr/local/sbin/nut-tool-ssh-gate" ssh-ed25519 AAAA... nut-tool shutdown-only
```

The controller can therefore request only:

```text
nut-tool-check
nut-tool-shutdown
```

The shutdown request invokes only:

```text
sudo -n /usr/local/sbin/nut-tool-remote-poweroff
```

The systemd helper schedules poweroff two seconds in the future so the SSH request
can receive exit status 0 before `sshd` is stopped.

## 4. Build known_hosts

Use the exact addresses configured in `config.toml`:

```bash
: > known_hosts
ssh-keyscan -T 5 -t ed25519 192.0.2.10 >> known_hosts
ssh-keyscan -T 5 -t ed25519 192.0.2.11 >> known_hosts
ssh-keyscan -T 5 -t ed25519 192.0.2.20 >> known_hosts
chmod 0644 known_hosts
```

For a non-standard SSH port:

```bash
ssh-keyscan -T 5 -p 2222 -t ed25519 192.0.2.50 >> known_hosts
```

Do not blindly trust `ssh-keyscan`; verify each fingerprint against the target's
actual host public key, for example on the target:

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

and on the controller/workstation:

```bash
ssh-keygen -lf known_hosts
```

## 5. Configure nut-tool

```bash
cp config.example.toml config.toml
nano config.toml
```

At minimum replace:

- NUT UPS name if not `ups`
- host IP addresses
- MAC addresses
- WOL broadcast/directed-broadcast destinations
- shutdown and wake priority values
- thresholds

Prefer IP addresses for controller-to-host communication. It avoids turning DNS
into another dependency during a power event.

### Priority semantics

Lower numbers run first.

Example shutdown:

```text
priority 10: compute/hypervisor/application hosts
priority 20: storage
priority 30: infrastructure that should be last
```

Wake can use the reverse ordering:

```text
priority 10: storage/network dependency
priority 20: compute
```

Within a shutdown priority group, up to `max_concurrent_ssh` hosts are processed
concurrently. Failed hosts are retained and retried in later passes. The retry
budget is finite so one dead target cannot consume the entire UPS runtime.

Wake priority groups are gated: a group receives its retry budget before later
wake priorities proceed (unless configured to stop on a failed group).

## 6. Validate before running

With the actual config/key/known_hosts available:

```bash
./nut-tool --config ./config.toml check
```

This checks:

- config syntax and invariants
- NUT connectivity
- `ups.status`
- `battery.charge`
- local key/known_hosts permissions
- each shutdown host's forced SSH `nut-tool-check` command
- WOL MAC/destination syntax

Inspect state without modifying it:

```bash
./nut-tool --config ./config.toml status
```

Test one target's harmless SSH gate:

```bash
./nut-tool --config ./config.toml test-ssh pve-1
```

Send a manual WOL burst:

```bash
./nut-tool --config ./config.toml wake pve-1
```

Run the full controller without destructive operations:

```bash
RUST_LOG=debug ./nut-tool --config ./config.toml --dry-run
```

CLI policy overrides work without a subcommand, e.g.:

```bash
./nut-tool \
  --config ./config.toml \
  --time-on-battery 10 \
  --low-battery-percent 50 \
  --wake-battery-percent 80
```

`--time-on-battery` is in minutes.

## 7A. Deploy as a systemd service

On the controller:

```bash
sudo ./deploy/systemd/install-controller.sh \
  ./nut-tool \
  ./config.toml \
  ./id_ed25519 \
  ./known_hosts
```

The installer validates the full configuration as the `nut-tool` service account
before enabling the service.

Useful commands:

```bash
systemctl status nut-tool
journalctl -u nut-tool -f
sudo -u nut-tool /usr/local/bin/nut-tool \
  --config /etc/nut-tool/config.toml status
```

Persistent state is stored in:

```text
/var/lib/nut-tool/state.json
```

Never delete that file during a real outage unless you understand the current
physical state. If deliberate recovery requires resetting it:

```bash
sudo -u nut-tool /usr/local/bin/nut-tool \
  --config /etc/nut-tool/config.toml \
  reset-state --yes
```

## 7B. Deploy as a scratch container

First build the image from the project root:

```bash
nerdctl build -f deploy/build/Containerfile -t local/nut-tool:latest .
```

Prepare the runtime directory:

```bash
cd deploy/container
cp ../../config.toml ./config.toml
cp ../../id_ed25519 ./id_ed25519
cp ../../known_hosts ./known_hosts
chmod 0600 id_ed25519
mkdir -p state
```

Then:

```bash
nerdctl compose up -d
nerdctl compose logs -f nut-tool
```

The compose stack uses `network_mode: host`. This is intentional when `upsd` is
bound only to `127.0.0.1:3493`, and it also avoids a container bridge getting in
the way of WOL broadcast routing. The final image has no shell or package manager.

## 8. NUT behavior

`nut-tool` talks directly to `upsd` and issues:

```text
LIST VAR <ups-name>
```

It requires `ups.status` and `battery.charge`. `battery.runtime` is collected when
available but is informational in this version.

Relevant statuses:

```text
OL   utility/on-line
OB   on battery
LB   low battery
FSD  forced shutdown
OFF  output off
WAIT driver not ready
```

Policy:

- `OB` starts/persists the outage timer.
- configured time OR configured percentage reaching the limit latches shutdown.
- `OB LB` can immediately latch shutdown when `honor_nut_low_battery=true`.
- `FSD` can latch shutdown when `honor_nut_fsd=true`, including a coordinated FSD
  observed while otherwise on-line.
- NUT telemetry loss while previously confirmed `OB` does not reset the outage
  timer. If the time threshold expires while telemetry is unavailable and
  `shutdown_on_nut_loss_after_confirmed_ob=true`, shutdown is latched.
- telemetry loss during recharge invalidates the continuous-mains stability timer.
- telemetry loss during WOL inhibits additional WOL sends.

## 9. Controller survival is mandatory

Something must be able to observe utility recovery and send WOL after the other
machines have shut down.

Best design:

```text
UPS
 +-- servers/NAS/hypervisors (shut down)
 +-- small controller (keeps running)
      +-- NUT upsd/driver
      +-- nut-tool
```

If the UPS itself removes output power, the controller may also turn off. That is
still workable if the controller boots automatically when AC/output returns:
`state.json` allows nut-tool to resume `WAITING_FOR_MAINS`/`RECHARGING`, and the
stable-mains timer is deliberately restarted after a process restart before WOL.

## 10. Coordinate with upsmon

Do not accidentally create two authorities with conflicting shutdown policy.

If `upsmon` on the controller is configured to power the controller off on LB/FSD,
it can prevent this daemon from remaining alive long enough to send WOL. Decide
whether:

1. `nut-tool` is the orchestrator and `upsmon` is only an emergency/final safety
   mechanism; or
2. the normal NUT FSD/load-off sequence is authoritative and nut-tool is expected
   to resume from persistent state after controller power returns.

Existing NUT clients on target hosts may remain as a final emergency path, but
understand that they can independently decide to shut those hosts down.

## 11. WOL caveats

WOL is a layer-2/network-topology concern. A magic packet sent to one subnet's
broadcast address generally does not cross a router into another VLAN. Configure
`wol_destination` per host/network, e.g.:

```toml
wol_destination = "10.20.30.255:9"
```

and ensure the controller has a path that actually permits the directed/local
broadcast. The target NIC/firmware must also have WOL enabled.

If `wake_check_port` is set, nut-tool repeats WOL until that TCP port becomes
reachable or the configured wake retry budget is exhausted. A successful UDP
send by itself is not treated as proof that a machine booted.

## 12. Failure/restart semantics

- Shutdown success is persisted per host immediately.
- A failed SSH target does not block first attempts to other hosts.
- Failed targets are retried in bounded passes with capped exponential backoff.
- Once shutdown is latched, power restoration does not cancel it.
- A process restart during `SHUTTING_DOWN` resumes only pending hosts.
- A process restart during `WAKING` returns through `RECHARGING` and requires a
  fresh stable-mains interval before sending more WOL packets.
- State file writes use write+fsync+rename+directory-fsync semantics.
- If state persistence itself fails, the daemon returns an error rather than
  continuing destructive actions without durable bookkeeping.

## 13. Safe end-to-end testing

Use NUT's `dummy-ups` driver for state-machine testing rather than repeatedly
pulling utility power. It is specifically intended for development/testing and
can expose modifiable UPS variables.

A minimal conceptual dummy device contains values such as:

```text
ups.status: OL
battery.charge: 100
battery.runtime: 3600
```

Run nut-tool with `--dry-run` first. Exercise at least:

1. OL -> OB -> OL before threshold: no shutdown.
2. OB long enough to hit the time threshold: shutdown latches.
3. OB charge crosses percentage threshold first: shutdown latches.
4. OB LB: emergency shutdown latches.
5. one SSH host unreachable: others are attempted; failed host is retried.
6. NUT disappears while OL: no destructive action.
7. NUT disappears after confirmed OB: outage clock remains active.
8. utility returns during shutdown: shutdown still completes.
9. OL returns briefly then OB: no WOL.
10. OL is stable but battery below wake threshold: no WOL.
11. OL stable + battery threshold met: WOL occurs once per completed host.
12. controller process is killed/restarted during every major state.

Only after those tests should you perform a real UPS outage test with actual
shutdown enabled.
