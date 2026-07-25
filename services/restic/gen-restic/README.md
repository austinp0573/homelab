# gen-restic

## resource estimates

Rough idle / typical / peak guesses per container. Not measured on my hosts - ballpark from docs and common reports.

### gen-restic

| | CPU | RAM | disk | network |
|---|---|---|---|---|
| low | 0 when not run | n/a | generated files only | none |
| expected | brief CPU while rendering templates | ~30-80 MB during run | output compose/config small | none meaningful |
| high | short spike | ~100-150 MB | still small | none |

Generator/one-shot style container, not a long-running service.

Browser UI that builds a restic compose deploy tree.

It does not talk to restic, TrueNAS, or the compose stack under
`services/restic/compose/`. That tree is only the shape this generator
copies from.

## run

```bash
cd services/restic/gen-restic
cp .env.example .env
./scripts/up.sh
```

Open `http://127.0.0.1:8788` unless the bind/port in `.env` was changed.

```bash
./scripts/smoke.sh
./scripts/down.sh
```

## what it emits

Zip download includes:

- `compose.yml`
- `.env`
- `includes.txt` / `excludes.txt`
- `secrets/` (repo location, password, optional rest auth / aws / ntfy)
- `certs/` when a CA PEM is pasted
- scaffolding dirs (`empty-host/`, `staging/`, …)
- `DEPLOY.txt`
- `truenas/prune.sh` when that toggle is on

Scripts (`backup.sh`, helpers) are not generated. Copy those from the
compose template when deploying.

## secrets

Typed secrets stay in memory only. The draft without secrets is saved in
localStorage. Use **forget secrets** to clear them from the page.


&nbsp;

**466f724a616e6574**
