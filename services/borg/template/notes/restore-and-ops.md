# restore and ops

these commands assume the copied deployment directory has a working `.env`, secrets, and config.

## list repositories and archives

```sh
nerdctl compose run --rm borgmatic borgmatic --config /etc/borgmatic/config.yaml list
```

## list files in archives

```sh
nerdctl compose run --rm borgmatic borgmatic --config /etc/borgmatic/config.yaml list --archive latest
```

## extract files

restore into a mounted output path, not over the live filesystem.

add a writable restore mount in `compose.yml` when needed.

example mount target.

`/restore`

then run extract with the paths to restore.

```sh
nerdctl compose run --rm borgmatic borgmatic --config /etc/borgmatic/config.yaml extract --archive latest --path source/host/home
```

## mount an archive

mounting needs fuse support from the host and extra container permissions.

for most restores, extract is simpler.

use mount only when browsing a large backup is worth the extra setup.

## check

the default run already includes check.

for a manual check.

```sh
nerdctl compose run --rm borgmatic borgmatic --config /etc/borgmatic/config.yaml check
```

## info

```sh
nerdctl compose run --rm borgmatic borgmatic --config /etc/borgmatic/config.yaml info
```

## break glass

keep a copy of these outside the backed up host.

the repository location.

the passphrase.

the ssh key or a maintenance key.

the borgmatic config used to create the archive.
