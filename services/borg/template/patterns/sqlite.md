# sqlite backup

borgmatic can dump sqlite databases before creating the archive.

the commented example in `config.yml` uses this shape.

```yaml
sqlite_databases:
  - name: app
    path: /source/app/app.db
```

mount the app data read only at `/source/app`.

for busy sqlite databases, prefer the borgmatic sqlite dump support over copying the database file directly.

if an app supports its own backup command, use that as a before action and back up the resulting dump file.

keep sqlite dumps in a path that is included by `source_directories`.
