# kasm env

standalone `kasmweb/desktop` image (not full Kasm Workspaces). HTTPS UI with self-signed cert. browser user is always `kasm_user`.

## `.env` / compose

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | `kasm` | compose project name; keep stable for volume/network naming. this is the single-container desktop image, not the multi-service Workspaces installer — don’t mix docs. renaming mid-flight orphans containers you still expect. Renaming mid-flight orphans volumes unless you migrate them on purpose. |
| `CONTAINER_NAME` | `kasm` | fixed container name for logs and proxy upstreams. only one desktop session model here — not a full orchestration plane. collision fails `up`. Proxy backends and smoke scripts often hardcode this string. |
| `RESTART_POLICY` | `unless-stopped` | desktop comes back after reboot; unsaved browser state inside may not. treat as a disposable workspace with Downloads persisted. stop explicitly when you don’t want it running. Use an explicit stop for maintenance; otherwise expect it back after reboot. |
| `KASM_IMAGE` | `kasmweb/desktop:1.19.0` | pinned desktop image; chrome/firefox workspace tags OK if you swap intentionally. major bumps change the VNC/web stack — smoke HTTPS login after. not the same as `kasmweb/workspaces` full suite images. This is the standalone desktop image, not full Kasm Workspaces. |
| `HOST_BIND` | `127.0.0.1` | keep on loopback and put HAProxy/Tinyauth in front. binding `0.0.0.0` exposes a full browser desktop to the LAN with only VNC password — usually too much. remote access should be via your edge/VPN story. Loopback plus an edge proxy is the usual safe exposure model. |
| `HOST_PORT` | `6901` | HTTPS UI port on the host. browsers will complain about the self-signed cert — expected. update proxy backends if you change it; HTTP on this port is the wrong mental model. Change the left-side publish and update every caller in the same commit. |
| `DATA_DIR` | `./data` | → `/home/kasm-user/Downloads` **only**. do not mount over `/home/kasm-user` or you break the image’s user home layout. persistence is downloads/files you save there, not the whole desktop profile. Wipe equals data loss unless you have a restore you have actually rehearsed. |
| `SHM_SIZE` | `1gb` | Chrome needs decent `/dev/shm` (docs say 512m; 1gb safer). Too small yields tab crashes and black screens that look like Kasm is broken. Raise further on heavy tabs if the host has RAM. Check `df -h /dev/shm` inside the container before blaming the image or VNC password. |

## secrets

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `VNC_PW` (`secrets/vnc.env`) | `<secret>` | browser/VNC password; copy from `vnc.env.example` and set a real value. this is the only gate if the port is reachable — treat it seriously. rotating requires updating the env file and recreating the container. Keep the real value out of git and shell history. |

proxy in front must not steal `Authorization` if also using basic auth. long tunnel timeouts + `ssl verify none` for the self-signed upstream.
