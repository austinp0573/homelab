# borg compose.yml setup

borgmatic container repo: [https://github.com/borgmatic-collective/docker-borgmatic](https://github.com/borgmatic-collective/docker-borgmatic)

host agnostic directory structure:
```bash
~/borgmatic/
+-- compose.yml         <- The nerdctl/docker compose file (same template everywhere)
+-- .env                <- BORG_PASSPHRASE and other secrets (gitignored)
+-- config/
|   +-- config.yaml     <- borgmatic config (edit source paths and repo URL per host)
+-- ssh/
|   +-- id_ed25519      <- Private key (chmod 600, gitignored)
|   +-- id_ed25519.pub  <- Public key (added to TrueNAS authorized_keys)
|   +-- known_hosts     <- TrueNAS host fingerprint (auto-populated on first connect)
+-- cache/              <- Borg chunk cache (critical for dedup, gitignored)
```

## after configuration repo-create in the container

documentation: [https://borgbackup.readthedocs.io/en/latest/usage/repo-create.html](https://borgbackup.readthedocs.io/en/latest/usage/repo-create.html)


&nbsp;

**466f724a616e6574**
