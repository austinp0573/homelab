# nutify config

thin snapshot under `nutify-tested-on-nanopi/` — **not** the live env-driven stack. real knobs live in `services/lab-ups/` (preferred) and `lab-ups/ups-stack/`.

## this tree (hardcoded compose)

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| image | `dartsteven/nutify:latest-raspberrypi5-arm64` | Pi5/arm64-oriented tag from the tested snapshot; wrong arch won’t run. prefer the lab-ups stack for env-driven deploys instead of editing this frozen compose. pin once you’ve validated a digest on your NanoPi. Pin once the stack is boring; floating tags are for active testing only. |
| `SECRET_KEY` | `<secret>` | Flask session signing key — change any baked test value or sessions are forgeable by anyone who read the repo. rotating logs everyone out (expected). not the NUT client password. Keep the real value out of git and shell history. |
| `UDEV` | `1` | enables udev-related behavior for USB UPS detection in the container. USB passthrough + privileged still required; this flag alone isn’t enough. leave on for HID UPSes. Still need USB passthrough and privileged; this flag alone never finds the UPS. |
| `LOG` | `true` | turns on Nutify logging paths used with the other LOG_* knobs. off makes dead-USB debugging painful. pair with LOG_LEVEL. Ignore this until the template actually wires it through. |
| `LOG_LEVEL` | `INFO` | app log verbosity; DEBUG is noisy but useful during driver/wizard pain. not NUT’s own debug — that’s separate. dial back after the UPS is stable. Dial back to INFO after the UPS path is stable. |
| `LOG_WERKZEUG` | `true` | Flask/Werkzeug access-style logs. helpful to see UI hits; noisy under healthcheck spam. turn off if logs drown the signal. Turn off if healthchecks drown the logs you care about. |
| `ENABLE_LOG_STARTUP` | `Y` | extra startup logging for bring-up. useful once; permanent Y is fine on a Pi. set N if you want quieter boots. Useful during bring-up; not a substitute for NUT driver debug. |
| `SSL_ENABLED` | `false` | TLS inside Nutify off — terminate TLS at the edge if needed. enabling needs cert mounts this snapshot may not wire. don’t assume HTTPS on 5050 without configuring it. Terminate TLS at the edge unless you wired certs into Nutify on purpose. |
| ports | `3493`, `5050`, `443` | NUT TCP + UI (+ 443 if SSL path used). 3493 must be reachable by upsmon clients; 5050 is the web UI. publishing all three on a shared host can surprise you — know what’s intentional. Update proxies and bookmarks in the same change as the listen edit. |
| privileged + USB | required | Nutify/NUT need USB device access; privileged is the blunt hammer this image expects. without USB, wizard never sees the UPS. host udev quirks still apply — cable/port matter. Without the device, the wizard never sees a UPS no matter how pretty the UI is. |

see `lab-ups/overview-env.md` for the full production-oriented env tables.
