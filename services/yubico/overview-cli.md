# yubico cli

import path in this tree: Google Authenticator QR → `extract_otp_secrets` → Yubico Authenticator (drop file) and/or `ykman oath …`. after any secret-handling run, shred the leftovers.

## extract_otp_secrets

binary name in the notes is `./extract` (upstream: `extract_otp_secrets`). no infiles → GUI camera capture.

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `infile …` | camera GUI | `otpauth-migration://…` text, `-` stdin text, QR image file, or `=` stdin image. `#` lines ignored in text. Multiple infiles merge exports — easy to duplicate accounts. Treat every infile as `<secret>`. |
| `-h, --help` | — | Full flag list for this build. Decoder backends differ by extras installed. Check before scripting. Does not touch the YubiKey. |
| `-c, --csv FILE` | — | CSV export; `-` = stdout. Spreadsheet-friendly but lingering files are a leak. Prefer stdout piped into the next tool then shred intermediates. Columns vary by version. |
| `-k, --keepass FILE` | — | KeePass totp/hotp CSV; `-` = stdout. Import path into KeePass — not ykman. Still `<secret>` on disk. Do not confuse with native KeePassXC otp fields without checking format. |
| `-j, --json FILE` | — | JSON; `-` = stdout. Best for programmatic ykman loops. Pretty-printed secrets linger in scrollback if printed. Shred files after import. |
| `-t, --txt FILE` | — | Plain text (notes example). `-` = stdout. Example: `./extract --txt output_file.txt qr_code.png`. Easiest to read; easiest to leak. Shred immediately after transfer. |
| `-u, --urls FILE` | — | otpauth URL list; `-` = stdout. Feeds `ykman oath accounts uri` well. One URL per line. Still full secrets in query params. |
| `-p, --printqr` | — | Print QR as text in the terminal. Handy without a phone; terrible on shared screens. Does not write files. Pair with careful terminal clear. |
| `-s, --saveqr DIR` | — | Write QR images into DIR. DIR fills with secrets-as-images — shred/rm aggressively. Useful for Yubico Authenticator drop imports. Create empty DIR first. |
| `-C, --camera NUMBER` | `0` | Camera index for GUI capture. Wrong index opens the wrong device or fails. Headless hosts should pass infiles instead. Prefer file QR inputs on servers; camera mode is for workstation migration sessions. |
| `-Q, --qr MODE` | `ZBAR` (typical) | `ZBAR` `QREADER` `QREADER_DEEP` `CV2` `CV2_WECHAT` — depends on build. Wrong mode = decode fail on valid QR. Try alternate modes before reshooting. If one decoder fails on a crisp image, switch modes before assuming the QR is bad. |
| `-i, --ignore` | off | Ignore duplicate OTPs when merging. Without it, duplicates may error or double-add downstream. Use when re-scanning the same migration QR. Use when re-extracting the same Google Authenticator migration payload. |
| `-n, --no-color` | off | Disable color — better for log capture. No security impact. Handy over dumb pipes. Keeps scripted captures clean when you redirect stdout to a file you will shred. |
| `-V, --version` | — | Tool version. Verify against the release you checksummed. Mismatched builds may lack QR backends. Checksum the binary you run — version alone does not prove integrity. |
| `-d, --debug` | off | Mutually exclusive with `-v`/`-q`. Noisy; may print sensitive paths. Use briefly. May echo paths to secret exports; clear the terminal after. |
| `-v, --verbose` | off | Extra progress without full debug. Still watch for secrets in output. Conflicts with quiet/debug. Prefer over debug for normal runs; escalate only when decode fails mysteriously. |
| `-q, --quiet` | off | No stdout except outputs forced by `-`. Auto when an export target is `-`. Good for scripts. Errors still matter — check exit codes. |

example from notes: `./extract --txt output_file.txt qr_code.png`. verify the release sha256 before running. treat every export as `<secret>` and shred when done.

## ykman (base)

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `-d, --device SERIAL` | first key | Pick YubiKey by serial when several are plugged in. Wrong device writes OATH to the spare key in your drawer. `ykman list -s` first. Not combinable with `--reader` casually. |
| `-r, --reader NAME` | — | Smart-card reader path; not with `--device` / `list` in conflicting ways. Needed for some laptop reader setups. Wrong reader looks like “no YubiKey”. Laptop reader names change across docks — re-list readers after hardware changes. |
| `-l, --log-level LEVEL` | off | `error` `warning` `info` `debug` `traffic`. `traffic` is extremely verbose and may include sensitive APDU-ish detail — avoid on shared consoles. Default off is correct; enable temporarily then disable so traffic logs do not linger. Cross-check against neighboring rows before changing -l, --log-level LEVEL alone. |
| `--log-file FILE` | stderr | Requires `--log-level`. Log files can capture secrets-adjacent data — shred later. Useful for support dumps. Shred the log file after you extract the troubleshooting bits you need. |
| `--diagnose` | — | Troubleshooting dump for upstream. Review before pasting into chats — may include serials/config. Does not change key state. Sanitize serials if you paste into public issues. |
| `-v, --version` | — | ykman version (not firmware). Firmware via `info`. Mismatches explain missing OATH flags (5.9+ features). Upgrade ykman before blaming the key when `accounts import`/`--generate` are “missing” — those need both new enough CLI and YK 5.9+ firmware. |
| `--full-help` | — | Includes hidden commands. Explore carefully — hidden ≠ safe. Prefer documented oath path for GA import. Hidden reset/config commands can wipe apps — stay in `oath` for this import path. |
| `list` | — | Connected keys overview. Start every session here when multiple keys exist. Empty list = udev/permission problems often. Always list before bulk add when more than one key is plugged in. |
| `list -s, --serials` | — | Serials only — script-friendly. Feed into `--device`. No secrets. Script-friendly serials for looping `--device` in dual-key setups. |
| `list -r, --readers` | — | Readers. Debug “device not found” before blaming ykman oath. Reader problems often look identical to missing udev rules — check both. Cross-check against neighboring rows before changing list -r, --readers alone. |
| `info` | — | Device + apps enabled. Confirm OATH is enabled before adding accounts. FIPS notes appear here on supported keys. If OATH is disabled in config, adds will fail until you re-enable the app. |
| `info -c, --check-fips` | — | YubiKey 4 FIPS only. Errors on non-FIPS — ignore unless you care. Not part of GA import. Ignore on non-FIPS keys; the error is expected. |
| `config` / `fido` / `otp` / `piv` / `openpgp` / `hsmauth` | — | Other apps; not the GA→Yubi import path. Easy to wipe the wrong app if exploring reset commands. Stay in `oath` for this workflow. Resetting the wrong app is irreversible without backups — do not explore casually. |
| `script FILE` | — | Run python against the key — only scripts you trust. `-f` force. Equivalent to running untrusted code with key access. Avoid unless you wrote it. |

## ykman oath

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `oath info` | — | OATH app status (version, password protected?, etc.). Check before bulk import. Passworded OATH needs `-p`/`-r` on later commands. If info shows OATH disabled, fix `config`/`info` first — bulk `accounts add` will fail in ways that look like bad secrets. |
| `oath reset` | — | **Wipes all OATH accounts**. `-f` skip confirm. No undo. Only when intentionally reloading the key. Confirm serial with `--device` first. |
| `oath access change` | — | Set/change OATH password. `-c` clear; `-n` new password; `-p` unlock; `-r` remember. Forgetting the password bricks OATH until reset. Remember (`-r`) stores on this machine — shared hosts beware. |
| `oath access remember` | — | Store password on this machine. `-p` to unlock first if needed. Convenience vs theft tradeoff. `forget` to clear. |
| `oath access forget` | — | Drop stored password. `-a` all. Next command will prompt. Does not clear the key’s password, only local cache. |

### accounts

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `accounts list` | — | List. `-H` show hidden; `-o` oath-type; `-P` period; `-p`/`-r` password. Verify imports landed before shredding source exports. Empty list after add = wrong device. |
| `accounts code [QUERY]` | — | Generate codes. HOTP / touch need a single match. `-s` single code only; `-H` hidden; `-p`/`-r`. Ambiguous QUERY errors instead of guessing — good. Touch timeout feels like failure. |
| `accounts add NAME [SECRET]` | TOTP, SHA1, 6 digits, period 30 | SECRET base32; omit to prompt. Defaults match most GA entries. Wrong algorithm/digits = valid-looking wrong codes. Name collisions need `--force` or rename. |
| `add -i, --issuer TEXT` | — | Issuer label shown in apps. Improves list readability. Stored separately from NAME depending on YK version. Match GA issuer when possible. |
| `add -a, --algorithm` | `SHA1` | `SHA1` `SHA256` `SHA512`. Must match the account’s provisioning. SHA1 still dominates GA exports. Wrong algo = desync forever. |
| `add -d, --digits` | `6` | `6` `7` `8`. Rare accounts use 8; wrong length fails auth. Match the otpauth URL. Most GA exports are 6; only change when the otpauth URL says otherwise. |
| `add -P, --period` | `30` | TOTP seconds. Almost always 30; 60 exists. Mismatch drifts codes. Hotp ignores period. |
| `add -o, --oath-type` | `TOTP` | `TOTP` / `HOTP`. GA migration is usually TOTP. HOTP needs counter discipline. Wrong type = useless codes. |
| `add -c, --counter` | — | HOTP initial counter. Must match server state or first codes fail. Easy to get wrong when re-importing. Re-importing HOTP without the right counter desyncs until the server catches up — painful. |
| `add -t, --touch` | off | Require touch to generate. Safer against silent malware reads. Annoying for high-churn accounts. Cannot always retrofit without delete/re-add. |
| `add -f, --force` | off | No prompt on overwrite/conflict. Dangerous in bulk scripts. Prefer explicit delete+add when unsure. Force overwrite replaces the existing account slot; know what you are clobbering. |
| `add -g, --generate` | off | Random key (YK 5.9+); not with SECRET. For new accounts you will register elsewhere — not for GA import. Generated secrets must be registered with the service separately — useless for GA migration. Never combine `-g` with an extracted otpauth secret; you will overwrite the slot with a key the issuer does not know. |
| `add -O, --output FILE` | — | Also write PSKC (5.9+). FILE is secret material — shred after. Useful for backup-to-second-key workflows. Prefer pairing with `--pskc-passphrase` so a leftover FILE on disk is not cleartext OTP seed material waiting to be imported elsewhere. |
| `add --pskc-key` / `--pskc-passphrase` | — | Encrypt that PSKC output. Prefer passphrase over leaving clear PSKC. Still shred afterward. Encrypted PSKC is still a secret file until shredded; treat the passphrase as `<secret>`. |
| `add -p` / `-r` | — | Unlock / remember OATH password for this invocation. Required when OATH is password-gated. `-r` persists locally. Remembered passwords live on the host — skip `-r` on shared workstations. |
| `accounts uri URI` | — | Add from `otpauth://…`. `-t` touch; `-f`; `-p`/`-r`. Best path from `--urls` export. URI query holds the secret — keep out of shell history (prefer file). |
| `accounts import FILE` | — | PSKC import (**YK 5.9+**). `-f` add all without prompts (overwrites same name); `-t` touch; `-p`/`-r`. Firmware too old = command missing. Use `--device` when multiple keys are plugged in — `-f` on the wrong serial silently overwrites the spare key’s OATH slots. |
| `accounts rename QUERY NAME` | — | YK 5.3+. `issuer:name` form for issuer. `-f`; `-p`/`-r`. Renaming beats delete/re-add when only labels are wrong. |
| `accounts delete QUERY` | — | `-f`; `-p`/`-r`. Permanent for that account on the key. Confirm QUERY uniquely matches. Does not affect other apps on the key. |

Yubico Authenticator 7.4.0 GUI path in the notes (drop QR export file on the app) is separate from ykman — use whichever fits; still shred intermediates.

## shred (cleanup)

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `-v` | off | Verbose. Notes prefer this so you see passes complete. No extra security. Good on large exports. |
| `-n N` | `3` (notes) | Overwrite passes; notes use `3`. Diminishing returns on SSD. Do not treat as cryptographic erase guarantee. Three passes matches the lab aliases; more is theater on flash storage. |
| `-z` | off | Zero final pass. Included in the recommended one-liner. Slightly slower. Pair with `-u` so you do not leave a zeroed file named like the export. |
| `-u` | off | Unlink when done. Without it the filename remains as garbage-filled. Always use after OTP exports. Without unlink, the secret filename remains in the directory listing as a breadcrumb. |

`shred -v -n 3 -z -u filename.txt` after the transfer. assume the machine may have swapped/cached copies — reboot / careful workspace hygiene for high-value secrets.
