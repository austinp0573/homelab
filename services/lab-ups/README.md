# Power Control

A UPS shutdown and restore stack for a NanoPi (or similar SBC) with a USB UPS attached. It covers the full outage cycle: detecting a low battery, telling connected hosts to shut down, cutting UPS output power once they're down, then waking everything back up after utility power returns and the battery has recharged enough.

The core pieces are stock containers, [Nutify](https://github.com/DartSteven/nutify) for the NUT server and monitoring UI, [UpSnap](https://github.com/seriousm4x/upsnap) for Wake-on-LAN and manual shutdown, plus a few small helpers built here.

## A Brief Discussion

Essentially I had a few problems to solve. Because my lab UPS is a APC BR1500MS2, there is no way to define a `restart if capacity exceeds: <var>%`. This is a problem for a few reasons, but the biggest one is that if the power flaps at all, then the UPS could resume providing power when it is already quite drained and I don't really have any way to create the logic to tell it to just stay off until the battery regains some level of charge. The only 2 things I have attached to it that are not potentially subject to NUT are my switches, and while they do not draw very much power, it is concievable during an intermittent power event, they would run the battery down quite low. If, once power were resumed, all the hosts just turned on all at once, the UPS could probably handle that, but probably isn't acceptable for production, and while my homelab is hardly production, I enjoy treating it like it is and solving problems in accordance with that perspective. 

In order to keep all of the hosts from just coming to life when the power is once again restored to the UPS outlets, I need change all the host's BIOS settings to `after AC loss: power off`. Which means that when power has been restored, even if the UPS is fully prepared, all of the attached hosts remain in a state of slumber. The obvious solution to this is to use `WAKE-ON-LAN` to bring them back to life.

Just solving those 2 aforementioned problems would not have actually required much effort. Just solving those 2 problems in a docker container, would also, not have required much effort. Unfortunately for me, while the world can be a bleak place, it is also a place where really remarkable engineers make really remarkable open-source things. Before I decided, "**if it happens in the lab, it will be in code, and I will track that code with git**", I had used [Nutify](https://github.com/DartSteven/Nutify) and [UpSnap](https://github.com/seriousm4x/upsnap). They're great, and while I'm a sucker for doing everything that I reasonably can in the terminal, everyone loves a good web UI with pretty graphs and what not from time to time. Using the **Nutify** and **UpSnap** containers to provide `NUT-server` and `WAKE-ON-LAN` functionality added a meaningful layer of complexity. Especially given that I want all of this to be as **reproducable** and as **in code** as it possibly can be. While solving this, I actually figured out how to have both containers web UIs fully initialized as soon as they were started without a user having to do a manual initial web user/setup configuration. That was actually pretty snazzy, however the shear unspeakable mass of duck tape necessary to make all of that work, in addition to making everything else work, meant that it was not something that I was actually willing to deploy to production (not to mention, God help me, try to maintain).

I will admit that an engineer with more experience that I possess likely would have come up with a variety of ways to solve this that are significantly better than what I have done. I will also admit that the actual solution to my problem would be to create real software, not just use duck tape, absurdity, and madness to string someone else's software together. One day perhaps. While one needn't look for to see the duck tape, I actually think this is a rather elegant solution where I effectively achieved all of my desired outcomes. Additionally, and I think most crucially, **it works**, and it doesn't just work, it works precisely as I wanted it to.

## Restore-watcher's purpose

NUT's normal killpower flow expects the host OS to call `upsdrvctl -k` during shutdown, either from an init script or a systemd unit. That never fires when NUT is running inside Docker, because the container has no visibility into the host's shutdown sequence. So if you just run Nutify and rely on the built-in `upsmon`, your UPS will never get the signal to cut output power after shutdown completes — it'll drain the battery and die.

`restore-watcher` fixes this. It polls upsd, triggers FSD when battery or time thresholds are hit, and then sends `driver.killpower` via `upscmd` after a configurable delay. No Docker socket mount, no `nsenter`, no forked images needed.

## Shutdown sequence

When utility power fails, the UPS switches to battery. `restore-watcher` polls upsd every `POLL_INTERVAL` seconds. When battery charge hits `NUT_LOW_BATTERY_THRESHOLD` or the UPS has been on battery for `NUT_ON_BATTERY_SECONDS`, restore-watcher:

1. Writes `restore-state/shutdown-expected.json` with the reason, current charge, and timestamp.
2. Opens a raw TCP connection to upsd on port 3493, authenticates as the FSD user (`NUT_FSD_USER`), and sends `FSD <ups>`. upsd sets the FSD flag and broadcasts it to every connected `upsmon` client.
3. All `upsmon` clients see the FSD flag and wait their `FINALDELAY` before running `SHUTDOWNCMD` (`/sbin/shutdown -h now`). Short-FINALDELAY hosts like pve-01 and pve-02 go down first. The NanoPi (`sbc-01`) goes last.
4. After `KILLPOWER_DELAY` seconds from when restore-watcher first saw FSD active, it calls `upscmd driver.killpower`. This tells the NUT driver to instruct the UPS to cut output power after `offdelay` seconds.

If FSD is already active when restore-watcher starts (i.e., something else triggered it), restore-watcher still writes the flag and handles killpower. It doesn't matter who sent FSD.

## Restore and wake sequence

When utility power returns, `restore-watcher` sees `ups.status` go to `OL`. If `shutdown-expected.json` exists and battery has climbed to `RESTORE_WAKEUP_BATTERY_THRESHOLD`, restore-watcher authenticates to UpSnap and sends a wake request for each configured device. UpSnap broadcasts WoL packets to each device's MAC address. The flag file is deleted once wakes are sent.

The recharge threshold before waking is intentional — it avoids waking hosts into an immediate second shutdown if utility power returned briefly and flickered back off.

## Containers

**nutify** runs `upsd`, `upsmon`, and the USB UPS driver. It exposes the NUT protocol on port 3493 and a web UI on port 5050. Needs `privileged` and direct USB device access. Nutify writes its own `upsmon.conf` from its database on every restart, so nothing here touches that file.

**upsnap** is the Wake-on-LAN and manual shutdown UI. It runs in `network_mode: host` because WoL packets have to go out as LAN broadcasts — Docker bridge networks don't forward those. `NET_RAW` is for ICMP ping health checks.

**upsnap-ssh-init** is a one-shot that decodes the base64 SSH private key from `.env` and writes it to `upsnap-data/ssh/` before UpSnap starts. It's wired as a `depends_on` condition so the key is always there before UpSnap tries to use it.

**nut-policy-init** is a one-shot that patches `ups.conf` and `upsd.users` in `nutify-data/etc/nut/`. Run it after Nutify's initial setup and again whenever you change battery thresholds or credentials. Nutify needs a restart after this runs. It also strips out any `upsmon.conf` blocks that older versions of this stack injected.

**upsnap-init** is a one-shot that creates or updates device records in UpSnap via its REST API. Run it after you create the first UpSnap admin, and again whenever `UPSNAP_HOSTS_JSON` changes. It matches on MAC address or name, so it's safe to re-run.

**restore-watcher** is the long-running daemon. It polls NUT, triggers FSD and killpower, and wakes hosts on AC restore. Built from `restore-watcher/Dockerfile` (Python 3.13 Alpine + nut client tools from apk).

## First run

**1.** Copy `.env.example` to `.env` and fill in your values. At minimum you need: `NUTIFY_SECRET_KEY`, `NUT_CLIENT_USER`, `NUT_CLIENT_PASSWORD`, `NUT_FSD_USER`, `NUT_FSD_PASSWORD`, `UPSNAP_ADMIN_EMAIL`, `UPSNAP_ADMIN_PASSWORD`.

**2.** Generate the UpSnap SSH key if you want UpSnap's shutdown buttons to work over SSH:

```sh
ssh-keygen -t ed25519 -f ./upsnap_shutdown_key -C "upsnap-shutdown"
base64 -w0 ./upsnap_shutdown_key
```

Put the base64 output into `UPSNAP_SSH_PRIVATE_KEY_B64` in `.env`. The public key (`upsnap_shutdown_key.pub`) gets installed on target hosts in step 9.

**3.** Start Nutify and UpSnap:

```sh
docker compose up -d nutify upsnap
```

**4.** Open the Nutify web UI at `http://<nanopi-ip>:5050` and complete first-run setup. Nutify will write `ups.conf`, `upsd.conf`, and `upsd.users` to `nutify-data/etc/nut/`. Set `UPS_NAME` in `.env` to the exact UPS name you chose during setup.

**5.** Run the NUT policy injector and restart Nutify:

```sh
docker compose up nut-policy-init
docker compose restart nutify
```

This writes the battery threshold, `allow_killpower`, shutdown delays, and the two dedicated upsd users (`NUT_CLIENT_USER` for monitoring, `NUT_FSD_USER` for triggering FSD and killpower) into `ups.conf` and `upsd.users`.

**6.** Open the UpSnap web UI at `http://<nanopi-ip>:8090` and create the first admin account. Use the same email and password you set for `UPSNAP_ADMIN_EMAIL` and `UPSNAP_ADMIN_PASSWORD`.

**7.** Run the UpSnap provisioner, then bring everything up:

```sh
docker compose up upsnap-init
docker compose up -d
```

**8.** Install and configure the NUT client on the NanoPi itself, so it shuts down cleanly when FSD fires:

```sh
sudo NUT_SERVER=<nanopi-ip> \
     UPS_NAME=<ups-name> \
     NUT_CLIENT_USER=<value from .env> \
     NUT_CLIENT_PASSWORD=<value from .env> \
     NUT_FINAL_DELAY=120 \
     ./scripts/setup-nut-client.sh
```

or by placing `setup-nut-client.sh` and `.env` on a host and running:

```bash
sudo bash -c 'set -a; source .env; exec ./setup-nut-client.sh'
```

The `NUT_FINAL_DELAY` value here must be longer than `KILLPOWER_DELAY` in `.env` and longer than the FINALDELAY of any other NUT client on the network. The NanoPi needs to still be running when restore-watcher sends killpower.

**9.** Set up the shutdown user on each host that UpSnap will shut down over SSH. Run this on each target host:

```sh
sudo UPSNAP_PUBLIC_KEY='<contents of upsnap_shutdown_key.pub>' \
     ./scripts/setup-upsnap-shutdown-user.sh
```

- or by placing `setup-upsnap-shutdown-user.sh` and `.env` on a host and running:

```bash
sudo bash -c 'set -a; source .env; exec ./setup-upsnap-shutdown-user.sh'
```

This creates the `upsnap-shutdown` system user, installs the public key, and drops a sudoers entry so the user can run `/sbin/shutdown -h now` without a password.

## NUT clients on other hosts

Any other machine that should shut down cleanly during an outage (Proxmox nodes, etc.) needs to run `nut-client` pointed at the NanoPi. Run `setup-nut-client.sh` on each of them with a shorter `NUT_FINAL_DELAY` (5–30 seconds is fine — they just need to shut down before the NanoPi does).

## Timing

```
FSD fires
  + KILLPOWER_DELAY seconds     → restore-watcher sends driver.killpower
  + NUT_UPS_OFF_DELAY seconds   → UPS cuts output power
```

`KILLPOWER_DELAY` must be less than `NUT_FINAL_DELAY` (the NanoPi's upsmon FINALDELAY) so killpower fires while restore-watcher is still running. A reasonable setup:

- Other hosts FINALDELAY: 15–30s
- `KILLPOWER_DELAY`: 60s  
- `NUT_FINAL_DELAY` on sbc-01: 120s  
- `NUT_UPS_OFF_DELAY`: whatever your UPS driver needs (often 30–60s)

## UpSnap hosts JSON

`UPSNAP_HOSTS_JSON` must be a single-line JSON array in `.env`. Required fields: `name`, `ip`, `mac`. The provisioner matches existing records by MAC or name, so re-running upsnap-init updates rather than duplicates.

Useful optional fields: `netmask` (CIDR prefix length, usually `"24"`), `description`, `shutdown_command` (replaces the default command inside the SSH wrapper), `shutdown_timeout`, `ssh_user`, `ssh_key_path`, `ssh_options`. If you want to fully replace the SSH invocation, use `upsnap_shutdown_cmd` instead.

## Useful commands

```sh
docker compose config
docker compose up -d --build
docker compose logs -f --timestamps nutify upsnap restore-watcher
docker compose up nut-policy-init && docker compose restart nutify
docker compose up upsnap-init
docker compose exec restore-watcher upsc "$UPS_NAME@nutify:3493"
```

## Data layout

- `nutify-data/etc/nut/` — NUT config (bind-mounted into both nutify and nut-policy-init)
- `nutify-data/instance/` — Nutify SQLite database
- `nutify-data/logs/` — Nutify logs
- `upsnap-data/ssh/` — SSH key written by upsnap-ssh-init
- `upsnap-data` (Docker volume) — UpSnap PocketBase database
- `restore-state/` — `shutdown-expected.json` flag file, persists across container restarts
