# encryption and secrets

borg encryption is client side. truenas stores encrypted repository data.

the default here is `repokey-blake2`.

that is the practical default for most deployments. the encrypted key is stored in the repository, and the passphrase unlocks it. this makes restore simpler because the repo carries the encrypted key with it.

`keyfile-blake2` stores the encrypted key outside the repository. this reduces what is stored with the repo, but losing the key file means losing the backup. use it only when key file backup and recovery are already planned.

both modes still need a strong passphrase.

## passphrase file

the template uses this file.

`secrets/passphrase.txt`

inside the container it is mounted here.

`/secrets/passphrase.txt`

borgmatic reads it with `encryption_passcommand`.

this avoids putting the passphrase directly into `compose.yml` or `.env`.

## openbao later

the container should keep using stable paths.

openbao can hydrate `secrets/passphrase.txt` and `secrets/ssh/id_ed25519` before the backup starts.

another option is to replace `encryption_passcommand` with a command that reads directly from openbao. keep that command short and make sure restore hosts can run it too.

## chacha and aes

the template leaves encryption mode in `.env` as `BORG_ENCRYPTION`.

use `repokey-blake2` unless there is a specific reason to use a different cipher mode.

when using chacha, keep the same operational rule. the passphrase and key material matter more than the cipher choice for this setup.

## restore risk

back up the passphrase outside this directory.

if using `keyfile-blake2`, back up the borg key file outside this directory too.

test restore before trusting a new deployment.
