# secrets

put runtime secrets here after copying the template.

expected files.

`passphrase.txt`

`ssh/id_ed25519`

`ssh/known_hosts`

do not commit real secrets.

the passphrase file is mounted read only into the container. borgmatic reads it through `encryption_passcommand`.

this layout is meant to be easy to replace later with openbao. the container only needs files or commands at stable paths. openbao can hydrate those paths before the backup runs.


&nbsp;

**466f724a616e6574**
