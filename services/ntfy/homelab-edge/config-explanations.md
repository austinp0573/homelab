# config explanations

main file: `config/server.yml` (from `server.yml.example`).

ntfy also stores state outside yaml:

- `data/auth.db` - users, ACLs, tokens (created by CLI helpers)
- `data/webpush.db` - browser push subscriptions (after web push keys are set)
- `cache/cache.db` - recent messages
- `cache/attachments/` - upload cache, capped at 100 MiB

---

## base-url / behind-proxy

`base-url` must be the public HTTPS name clients and publishers use (`https://ntfy.example.com`).

`behind-proxy: true` when haproxy (or anything) terminates TLS in front. without it, scheme/IP handling gets weird.

---

## listen-http

inside the container this is `:80`. host port is `HOST_PORT` in `.env` (default 2586 so it does not collide with headscale/gatus on 8080).

---

## auth

`auth-default-access: deny-all` - no ACL means no access.

`enable-login` / `require-login` - web UI needs a user.

`enable-signup` / `enable-reservations` stay disabled. Accounts and publisher users are created by the helper scripts.

do not put password hashes in server.yml for day-to-day use. create users with:

```sh
./scripts/bootstrap-admin.sh
./scripts/create-publisher.sh <topic>
```

those talk to `ntfy user` / `ntfy access` / `ntfy token` inside the container and write `auth.db`.

`create-publisher.sh` only accepts lowercase letters, numbers, hyphens, and underscores for topic names.

`replace-publisher.sh <topic>` deletes and recreates that publisher. This immediately revokes every token for the publisher.

`reset-admin-password.sh` changes the existing admin password.

---

## cache and attachments

message history stays in `cache/cache.db` for seven days.

attachments have these limits:

- 10 MiB per file
- 100 MiB total cache
- 25 MiB stored per visitor
- 100 MiB upload/download bandwidth per visitor per day
- 24-hour expiry

these are intentionally small for a notification service. increase them only if attachments are part of normal use.

---

## web push

optional. generate keys:

```sh
./scripts/webpush-keys.sh
```

paste public/private into server.yml, set `web-push-email-address`, recreate the container. skip until you care about browser push.

upstream `ntfy.sh` is omitted on purpose (iOS via upstream can wait).

---

## smtp

optional outgoing mail for "also email me" style notifies. block is in the example commented / placeholder. leave it alone until you have an SMTP relay. not required for phone app or gatus tokens.

---

## topics

topic names are not secret once ACLs exist, but still use boring names:

| topic | publisher |
|-------|-----------|
| gatus | edge/home uptime |
| restic | backup jobs |
| borg | borgmatic / borg |
| lab | ad-hoc scripts |
| watchtower | container update bots if you add one |

admin can read all. publishers write only their topic.
