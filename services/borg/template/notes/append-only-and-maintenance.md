# append only and maintenance

the truenas ssh users are expected to run borg serve with append only enabled.

that is good for backup clients. a compromised client can add new archives but should not be able to prune or delete old data through that ssh key.

the client side compose command runs only these actions.

`create check`

do not add prune, delete, or compact to the client command for append only users.

## maintenance side

prune and compact must run somewhere with write access.

this can be truenas itself, or another trusted host using a different ssh key that is not append only.

`scripts/truenas-maintenance.sh` is a simple starting point.

the script defaults to one repository.

```sh
REPO_PATH=/mnt/coldpool/borg/lab/sample-host ./scripts/truenas-maintenance.sh
```

it can also walk a repo root.

```sh
MODE=walk REPO_ROOT=/mnt/coldpool/borg/lab ./scripts/truenas-maintenance.sh
```

## passphrase on the maintenance host

encrypted borg repositories need key access for prune and check.

with `repokey-blake2`, the encrypted key is in the repo, but the passphrase is still needed.

if the maintenance script runs on truenas, truenas must have access to the passphrase or a passcommand.

that makes the maintenance host trusted.

if that is not acceptable for a deployment, run maintenance from a different trusted host with a non append only maintenance ssh key.

## truenas borg command

the restricted ssh command can use a borg binary outside the normal truenas system paths.

example shape.

`TMPDIR=/var/tmp /mnt/fastpool/bin/borg-server/borg serve --append-only --restrict-to-path /mnt/coldpool/borg/lab`

the client does not need to know that binary path. it only needs the ssh target and repository path.
