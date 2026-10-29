# ntfy scripts

Helper scripts for setup, user administration, and key generation.

## Host Setup

### setup-user.sh
Creates host system group/user (`ntfy`) and sets directory permissions on `./data` and `./cache`.

```sh
# Run with default UID/GID 1020
./scripts/setup-user.sh

# Custom UID/GID
PUID=1000 PGID=1000 ./scripts/setup-user.sh
```

---

## User & Password Management

### bootstrap-admin.sh
Creates an admin user in the running container via CLI (`ntfy user add --role=admin`). Uses password from `secrets/admin-password.txt` or prompts interactively.

```sh
./scripts/bootstrap-admin.sh
```

### reset-admin-password.sh
Changes the password for an existing admin user (`NTFY_ADMIN_USER`, default `admin`).

```sh
./scripts/reset-admin-password.sh
```

---

## Topic Publisher Management

### create-publisher.sh
Creates a dedicated publisher user (`pub-<topic>`), grants `write` access on `<topic>`, and generates an API token.

```sh
./scripts/create-publisher.sh <topic>
# Example: ./scripts/create-publisher.sh gatus
```

### replace-publisher.sh
Deletes an existing publisher user `pub-<topic>` (revoking its tokens) and recreates a fresh one.

```sh
./scripts/replace-publisher.sh <topic>
```

---

## Key Generation

### webpush-keys.sh
Runs `ntfy webpush keys` inside the container to generate VAPID public and private keys to paste into `server.yml`.

```sh
./scripts/webpush-keys.sh
```
