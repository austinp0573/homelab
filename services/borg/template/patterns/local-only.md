# local only backup

remove the remote repository entry from `config.yml`.

keep the local repository entry.

set `LOCAL_REPO_ROOT` in `.env` to the host directory that should hold local borg repos.

example.

`LOCAL_REPO_ROOT=/mnt/backup/borg`

set `BORG_LOCAL_REPO_PATH` to the container path for the repo.

example.

`BORG_LOCAL_REPO_PATH=/backup/repositories/workstation`

local repositories still use encryption.

do not store the only copy of the passphrase on the same disk as the local repository.
