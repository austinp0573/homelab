# init and first run

borg repositories are long lived. archives inside the repository are timestamped.

use a stable path like this.

`/mnt/coldpool/borg/lab/host1`

or this.

`/mnt/coldpool/borg/lab/special-backup-name`

## files to prepare

copy `.env.example` to `.env`.

create `secrets/passphrase.txt`.

put the ssh private key at `secrets/ssh/id_ed25519`.

create `secrets/ssh/known_hosts`.

run this after the secrets are in place.

```sh
./scripts/fix-ssh-permissions.sh
```

## known hosts

this writes the truenas host key to `secrets/ssh/known_hosts`.

```sh
./scripts/scan-known-hosts.sh
```

inspect the file before trusting it.

## init

run init once for each repository.

```sh
nerdctl compose run --rm borgmatic sh -c 'borgmatic --config /etc/borgmatic/config.yaml init --encryption "$BORG_ENCRYPTION"'
```

if both remote and local repositories are present in `config.yml`, borgmatic will initialize both.

remove the local repository or remote repository from `config.yml` before init if only one should be initialized.

## first backup

run a one shot backup.

```sh
nerdctl compose run --rm borgmatic
```

the default command runs create and check only.

it does not prune or compact.
