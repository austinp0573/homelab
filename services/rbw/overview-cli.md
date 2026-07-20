# rbw cli

unofficial Bitwarden CLI (`doy/rbw`). agent holds unlocked keys; `pinentry` required. config via `rbw config set KEY VALUE` → `~/.config/rbw`.

## top-level

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `-h, --help` | — | Prints help for the command/subcommand. Use on nested commands (`rbw get -h`) — top-level help is shallow. Does not touch the agent. Worth checking after upgrades for new flags. |
| `-V, --version` | — | Prints rbw version. Handy when pinentry/agent bugs are version-specific. Does not imply agent is running. Compare against distro vs cargo installs. |

## config

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `config show` | — | Print all settings. Verify `base_url` before blaming login. Does not show secrets from the vault. Good sanity check after SSO edits. |
| `config set KEY VALUE` | — | Set one option in `~/.config/rbw`. Wrong KEY is ignored/errors depending on version. Takes effect on next agent ops — restart agent if behavior looks sticky. After changing `base_url`/`identity_url`, `stop-agent` then `unlock` so you are not debugging a stale agent against the new endpoints. |
| `config unset KEY` | — | Reset one option to default. Useful to clear a bad `identity_url`. Does not log you out by itself. Confirm with `config show`. |
| `email` | *(required)* | Bitwarden/Vaultwarden account email. Wrong email looks like bad password. Required before login. Not a secret but identifies the account in configs. |
| `sso_id` | unset | SSO org id; unset = normal login. Set only for SSO orgs — otherwise login breaks. Clear with unset when leaving SSO. Distinct from client_id API keys. |
| `base_url` | `https://api.bitwarden.com/` | Self-hosted API root — for Vaultwarden set to your VW URL (often origin, check trailing slash). Wrong base_url is the #1 self-host footgun. Affects derived identity/notifications if those are unset. For Vaultwarden this is usually the public origin clients use, including scheme. |
| `identity_url` | derived / `https://identity.bitwarden.com/` | If unset: `/identity` on `base_url`. Override when your reverse proxy splits identity. Mismatch = OAuth/login weirdness. Official cloud default differs from self-host derive. |
| `ui_url` | `https://vault.bitwarden.com/` | Web vault URL for links/open actions. Set to your VW UI origin when self-hosting. Wrong ui_url only breaks convenience opens, not unlock. Set it when you care about `rbw` opening the web UI; unlock still works if wrong. |
| `notifications_url` | derived / notifications.bitwarden.com | If unset: `/notifications` on `base_url`. Rarely critical for CLI get/list. Mis-set can spam errors in agent logs. Derived path is fine for VW; only override if your proxy splits notifications oddly. |
| `lock_timeout` | `3600` | Seconds keys stay in memory after unlock. Lower is safer on shared machines; higher is less pinentry annoyance. `0` behavior depends on version — do not assume forever. Expiry mid-script fails `rbw get`. |
| `sync_interval` | `3600` | Auto-sync while agent runs; `0` disables. Stale local DB after server changes if sync is off. Too aggressive hammers VW. Manual `rbw sync` still available. |
| `pinentry` | `pinentry` | Pinentry binary (`pinentry-tty` on headless). Wrong binary = silent hang waiting for GUI. SSH sessions often need `pinentry-tty` or `PINENTRY_USER_DATA`. Test with `unlock` after changes. |

self-hosted Vaultwarden: set `base_url` (and usually identity/notifications fall out correctly).

## session / agent

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `register` | — | Device registration with personal API key (bot detection on official server). Do this before password login if required. Not usually needed on VW. Failed register blocks login loops. |
| `login` | — | Log in (pinentry for password/2FA as needed). Creates local encrypted db. Wrong base_url fails here. Re-login after purge. |
| `unlock` | — | Unlock local db into agent memory. Required before `get`/`enc` aliases. Timeout controlled by `lock_timeout`. Fails closed if pinentry broken. |
| `unlocked` | — | Exit status / check if unlocked — scripts should test this before `get`. Nonzero means locked. Does not unlock by itself. Quiet enough for hooks. |
| `sync` | — | Pull server → local. Needed after adding keys in the UI. Conflicts rare but possible; sync before relying on new entries. Network errors leave stale data without clear noise. |
| `lock` | — | Lock db (keys out of memory). Do this on shared hosts after use. Running aliases after lock fail closed (good). Does not stop the agent process. |
| `purge` | — | Delete **local** copy only — not the server vault. Next login rebuilds. Use when local db corrupts. Scary name — double-check you are not on the wrong machine. |
| `stop-agent` | — | Kill background agent. Clears in-memory keys as a side effect. Needed after some upgrades. Next command respawns agent. |

## read / search

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `list` / `ls` | — | List entries. Output is names by default — good for discovery. Large vaults flood the terminal. Pair with `--fields` for scripting. |
| `list --fields FIELDS` | `name` | `id,name,user,folder,type` — tab-separated. Stable for scripts. Wrong field names error. Prefer over scraping default list. |
| `list --raw` | off | JSON output. Best for jq pipelines. Heavier than fields. Stable enough for automation. |
| `get NEEDLE [USER]` | — | Password (or field). NEEDLE = name / URI / UUID. Ambiguous names need USER or `--folder`. Lab age aliases: `rbw get crypt_pu` / `crypt_pr`. Vault must be unlocked. |
| `get --folder FOLDER` | — | Scope search to a folder. Avoids grabbing the wrong duplicate name. Folder must exist exactly. Combine with NEEDLE. |
| `get -i, --ignorecase` | off | Case-insensitive match. Handy for messy naming. Can increase ambiguity — pair with folder. Ambiguous matches still fail — folder/USER disambiguation beats ignorecase alone. |
| `get -f, --field FIELD` | password | Custom field / notes path depending on entry. Wrong field returns empty/errors. Use `--list-fields` first. Not only for password. |
| `get --full` | off | Include notes. Notes may contain more secrets — watch terminal scrollback. Heavier output. Good for recovering age key material stored as notes. |
| `get --raw` | off | JSON for the entry. Prefer for scripts over text. Still prints secrets — redirect carefully. Pipe to jq and keep the raw JSON off shared tmux scrollback when possible. |
| `get -c, --clipboard` | off | Copy result to clipboard. Needs a working clipboard backend on Wayland/X11/SSH. Failure mode is easy to miss. Do not use on shared screens. |
| `get -l, --list-fields` | off | List fields on the entry without dumping secrets (mostly). Use before `-f`. Helps decode custom field layouts. Custom fields for age key material show up here before you `-f` them. |
| `search TERM` | — | Find entries by term. Broader than get. Good when you forget exact names. Still needs unlock. |
| `search --fields` / `--folder` / `--raw` | same idea as list | Same shaping flags as list. Use `--raw` for tooling. Folder scoping reduces noise. Same field vocabulary as list; keep scripts consistent across both commands. |
| `code` / `totp NEEDLE [USER]` | — | TOTP for entry. Entry must have a totp field. Clock skew breaks codes — check NTP. Ambiguous NEEDLE same as get. |
| `code --folder` / `-i` / `--clipboard` | — | Scope/case/clipboard variants for TOTP. Clipboard same caveats as get. Ignorecase can hit wrong entry. TOTP clipboard copies expire from the clipboard agent on their own schedule — still treat as secret. |

lab age aliases: `rbw get crypt_pu` / `rbw get crypt_pr` — vault must be unlocked.

## write / generate

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `add NAME [USER]` | — | Opens `$VISUAL`/`$EDITOR`; first line = password, rest = note. Empty editor abort may still create depending on version — verify. Sync after add if another device needs it. First line is the password even when you meant the whole buffer to be a note — format matters. |
| `add --uri URI` | — | Attach a URI for browser matching. Wrong URI hurts autofill more than CLI get. Repeatable depending on version — check help. URI matching is for browser integrations; CLI `get` by name does not need it. |
| `add --folder FOLDER` | — | Place new item in folder. Folder must exist. Helps keep `crypt_*` keys organized. Create the folder in the UI first if `add` rejects a missing folder name. |
| `generate` / `gen LEN [NAME] [USER]` | — | If NAME given, also saves. LEN = chars, or word count with `--diceware`. Saving without looking at the value once is a footgun. Sync after save. |
| `generate --uri` / `--folder` | — | Same attachment options as add when saving. Ignored if you only print. Keep folder taxonomy consistent. Only applies when NAME is provided and the generated secret is saved. |
| `generate --no-symbols` | off | Alphanumeric-ish passwords for picky sites. Weaker charset — only when required. Combine carefully with length. Increase LEN when dropping symbols so entropy stays acceptable. |
| `generate --only-numbers` | off | Digits only — weak unless long. Rarely appropriate for vault master-adjacent secrets. Use long lengths or avoid for anything important. Cross-check against neighboring rows before changing generate --only-numbers alone. |
| `generate --nonconfusables` | off | Drop visually similar chars. Good for reading aloud. Slightly reduces charset. Slightly smaller charset — bump length if a site allows it. |
| `generate --diceware` | off | EFF word list; LEN = word count. Memorable; watch spaces in editors. Great for `crypt_pr` passphrases if you go that route. LEN is word count, not characters — `4` words ≠ 4 chars. |
| `edit NEEDLE [USER]` | — | Editor; same first-line/notes rules. Easy to corrupt age keys stored as notes — edit carefully. Sync after. After editing `crypt_pr`, test a decrypt immediately before shredding old copies. |
| `edit --folder` / `-i` | — | Disambiguate which entry to edit. Prefer folder on duplicate names. Ignorecase increases risk of wrong edit. Disambiguate before opening $EDITOR so you do not edit the wrong duplicate. |
| `remove` / `rm NEEDLE [USER]` | — | Delete entry. Local + sync to server — treat as real delete. No trash UI in CLI. Double-check NEEDLE. |
| `remove --folder` / `-i` | — | Scope/case flags for delete. Still permanent. Prefer UUID NEEDLE when scared. Sync after delete so other devices drop the entry too. |
| `history NEEDLE [USER]` | — | Password history. Useful after accidental overwrite. Not all item types keep useful history. Still needs unlock. |
| `history --folder` / `-i` | — | Disambiguation for history. Same ambiguity rules as get. History is per-item; it will not help if you deleted and recreated under a new name. Cross-check against neighboring rows before changing history --folder` / `-i alone. |

## completions

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `gen-completions SHELL` | — | `bash` `zsh` `fish` `powershell` `elvish` `nushell` `fig`. Emit once into your shell rc. Stale completions after upgrades miss new flags. Does not configure rbw itself. |

## aliases (`aliases.md`) — age wrappers

| name (key) | default value | purpose + notes |
| --- | --- | --- |
| `enc FILE` | — | `age -r "$(rbw get crypt_pu)" -o FILE.age FILE` then `shred -u -z -n 3 FILE`. Aborts if `.age` exists. Fails closed if rbw locked/key missing/age fails (original preserved). Needs bash-capable environment for command sub. |
| `dec FILE.age` | — | `age -d -i <(rbw get crypt_pr) -o FILE FILE.age` then shred the `.age`. Aborts if plaintext exists or extension wrong. Process substitution needs bash. Fails closed preserves ciphertext on error. |

both fail closed if rbw is locked / key missing / age fails (original preserved).
