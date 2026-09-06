# restic rest-server compose setup

Containerized Restic REST server deployment template configured for `nerdctl compose`.

Provides high-performance, append-only, authenticated REST endpoint storage for Restic backup clients.

---

## Directory Layout

```text
rest-server/compose/
├── compose.yml
├── .env.example
├── .gitignore
├── README.md
├── secrets/
│   ├── .gitkeep
│   └── .htpasswd.example
└── data/
    └── .gitkeep
```

---

## Setup & Deployment Instructions

### 1. Copy Environment Configuration
```bash
cp .env.example .env
chmod 600 .env
```

### 2. Generate Basic Authentication Credentials
Generate your HTTP Basic Auth `.htpasswd` file inside `./secrets/`:

```bash
# Using htpasswd utility (apache2-utils or httpd-tools)
htpasswd -Bb -c secrets/.htpasswd user_name password

# Set strict permissions
chmod 600 secrets/.htpasswd
```

*Note: If using `--private-repos` in `OPTIONS`, the username in `.htpasswd` will correspond to the subfolder name under `data/` (e.g. `data/backupuser/`).*

### 3. Deploy with nerdctl
```bash
# Start container stack using nerdctl
nerdctl compose up -d

# Check service logs
nerdctl compose logs -f
```

### **HAproxy config**

```bash
    option httpchk GET /
    http-check expect status 401
    server app1_node1 127.0.0.1:8000 check
```

#### Manage users

##### Add user

```sh
docker exec -it rest_server create_user myuser
```

or

```sh
docker exec -it rest_server create_user myuser mypassword
```

##### Delete user

```sh
docker exec -it rest_server delete_user myuser
```

---

## Configuration Options (`.env`)

| Variable | Default | Description |
| :--- | :--- | :--- |
| `REST_SERVER_PORT` | `8000` | Host port exposed for REST server connections. |
| `DATA_DIR` | `./data` | Host path where backup repositories are stored (e.g. BTRFS subvolume). |
| `PASSWORD_FILE` | `/run/secrets/.htpasswd` | Container path to the `.htpasswd` authentication file. |
| `DISABLE_AUTHENTICATION` | `""` (Empty) | Uncomment in `.env` to disable auth (setting any non-empty value disables auth). |
| `OPTIONS` | `--append-only --private-repos` | CLI options passed to `rest-server`. |

---

## Client Usage Example

On client machines sending backups to this REST server:

```bash
# Initialize restic repository
restic -r rest:http://backupuser:password@sbc-03.local:8000/backupuser/ init

# Run backup
restic -r rest:http://backupuser:password@sbc-03.local:8000/backupuser/ backup /opt
```
