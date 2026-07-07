# rbw setup

get the exectuables from:

https://github.com/doy/rbw

```bash
curl -LO https://github.com/doy/rbw/releases/download/1.15.0/rbw_1.15.0_linux_amd64.tar.gz
```

veryify the checksum:

```bash
# make sure to get the new checksum and not just use this one
$ CHECKSUM="d8174b0aeaccbcd80322ca41fb48bf2dbad8fc4d5d9c509c42bbb46d5e195395"
$ RBW_PATH="/full/path/to/the/location/of/rbw_1.15.0_linux_amd64.tar.gz"
$ echo "$CHECKSUM $RBW_PATH" | sha256sum -c
/full/path/to/rbw_1.15.0_linux_amd64.tar.gz: OK
```

extract the tar

```bash
tar xf rbw_1.15.0_linux_amd64.tar.gz
```

put the executables where they go

```bash
mv rbw rbw-agent /usr/local/bin
```

install the dependency

```bash
sudo apt update && sudo apt install pinentry-tty -y
```

make the config directory for `rbw`

```bash
mkdir -p ~/.config/rbw
```

## Configuration

Configuration options are set using the `rbw config` command. Available
configuration options:

* `email`: The email address to use as the account name when logging into the
  Bitwarden server. Required.
* `sso_id`: The SSO organization ID. Defaults to regular login process if unset.
* `base_url`: The URL of the Bitwarden server to use. Defaults to the official
  server at `https://api.bitwarden.com/` if unset.
* `identity_url`: The URL of the Bitwarden identity server to use. If unset,
  will use the `/identity` path on the configured `base_url`, or
  `https://identity.bitwarden.com/` if no `base_url` is set.
* `ui_url`: The URL of the Bitwarden UI to use. If unset,
  will default to `https://vault.bitwarden.com/`.
* `notifications_url`: The URL of the Bitwarden notifications server to use.
  If unset, will use the `/notifications` path on the configured `base_url`,
  or `https://notifications.bitwarden.com/` if no `base_url` is set.
* `lock_timeout`: The number of seconds to keep the master keys in memory for
  before requiring the password to be entered again. Defaults to `3600` (one
  hour).
* `sync_interval`: `rbw` will automatically sync the database from the server
  at an interval of this many seconds, while the agent is running. Setting
  this value to `0` disables this behavior. Defaults to `3600` (one hour).
* `pinentry`: The
  [pinentry](https://www.gnupg.org/related_software/pinentry/index.html)
  executable to use. Defaults to `pinentry`.

```bash
rbw config set KEY VALUE
```

```bash
mv completions/bash ~/.local/share/bash-completions/completions/rbw
chmod +x ~/.local/share/bash-completions/completions/rbw
```

add:

```bash
if [ -f ~/.local/share/bash-completion/completions/rbw ]; then
    source ~/.local/share/bash-completion/completions/rbw
fi
```
to `~/.bashrc`

---

&nbsp;

**466f724a616e6574**