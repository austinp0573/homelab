# Kubernetes Administrator Toolbox

An Alpine container for Kubernetes administration. [Dockerfile](Dockerfile) owns tool installation, [compose.yml](compose.yml) owns the service and mounts, and [.env](.env) owns non-secret settings.

## Before starting

Use a Linux host with containerd, nerdctl Compose, BuildKit, and working container networking. Builds need internet access. Commands below use the `default` containerd namespace; use the namespace selected for your deployment consistently. Add `sudo` if required by your runtime. Docker Compose is an alternative, but was not used for verification.

From the repository root:

```bash
cd compose-kubectl
id -u
id -g
vim .env
```

- Keep a local `.env`; it is ignored by Git. Check image/tool versions and shell preferences before building.
- Match `USER_UID` and `USER_GID` to the target host's writable storage. Local settings are `1000:1000`; the usual NAS uses `3000:3000`.
- Check `WORKSPACE_DIR`, `CLUSTER_CONFIG_DIR`, `STATE_DIR`, `DOTFILES_DIR`, and `SSH_CONFIG_FILE`. Relative paths resolve from this directory. Dotfile sources must already exist.
- Create host storage as the intended owner before starting a privileged runtime. Image ownership does not repair bind-mount ownership; account for UID remapping if enabled.

Prepare the default state layout in Bash, without sudo:

```bash
. ./.env
mkdir -p "$WORKSPACE_DIR" "$CLUSTER_CONFIG_DIR"
mkdir -p "$STATE_DIR"/{bash,kube,ssh,vim,sops/age}
mkdir -p "$STATE_DIR"/helm/{config,cache,data}
mkdir -p "$STATE_DIR"/xdg/{config/registry,cache,data,state}
```

Compose reads `.env` itself; sourcing above only supplies the directory variables. Exported host variables can override Compose settings.

## Build and use

Run on the host from this directory:

```bash
nerdctl --namespace default compose config
nerdctl --namespace default compose build
nerdctl --namespace default compose up -d
nerdctl --namespace default compose exec kube bash
```

The shell runs as the configured non-root user. Exiting Bash leaves the service running. Inside, `k` aliases kubectl with completion; the prompt shows local Kubernetes and Talos contexts.

Use `compose ps`, `compose stop`, and `compose start` with the same runtime prefix to inspect or pause the toolbox.

## Files and state

- `WORKSPACE_DIR` mounts at `/workspace`, the initial shell directory.
- `CLUSTER_CONFIG_DIR` mounts at `/config/cluster`. Currently it selects the host's `./workspace/new-talos-config/`. Default filenames are `kubeconfig` and `talosconfig`; change them through `KUBECONFIG_NAME` and `TALOSCONFIG_NAME`.
- `STATE_DIR` mounts at `/state`: history, Vim, SSH, Kubernetes cache, Helm, registry credentials, XDG data, and age keys survive recreation.
- The five repository dotfiles selected by `DOTFILES_DIR` mount writable. Editing them inside the toolbox changes the host files. SSH client configuration is mounted read-only.
- Helm and Krew plugins live in the image, not persistent state. Update them by rebuilding.

Kubeconfig certificate paths and authentication helpers must exist inside the container. Files outside bind mounts are disposable. Keep credentials out of Git and the build context; review ignore rules when changing paths and back up persistent data separately.

## Tool changes

Enable a commented tool by uncommenting its complete Dockerfile block and its Compose build argument and optional mounts, where present. Set its release in `.env` when it has a version setting. To omit a standalone tool, comment out its complete block and matching argument when present. Respect the marked Helm/Krew dependency families; do not leave dependent plugins enabled without their parent tools.

Rebuild after version, installer, or UID/GID changes:

```bash
nerdctl --namespace default compose build
nerdctl --namespace default compose up -d --force-recreate
```

Mount, environment, and port changes only need recreation. Recreation interrupts shells and port forwards, but does not fix host ownership. Use `compose build --no-cache` to refresh Alpine packages and the Krew index; those versions are not locked. Rebuilding client tools does not upgrade clusters.

## Port forwarding

Inside the toolbox, replace the namespace and service placeholders:

```bash
kubectl -n '<NAMESPACE>' port-forward --address=0.0.0.0 'service/<SERVICE>' "$FORWARD_CONTAINER_PORT:80"
```

Keep it running; the default host endpoint is `http://127.0.0.1:18080`. `FORWARD_BIND_ADDRESS`, `FORWARD_PORT`, and `FORWARD_CONTAINER_PORT` select the mapping. Keep the host bind on loopback unless remote access is intentional; the container listener is also reachable from its network.

## SOPS and age

Prefer an existing identity at the host path `$STATE_DIR/sops/age/keys.txt`, readable only by the configured owner. Set `SOPS_AGE_KEY_FILE=/state/sops/age/keys.txt` in `.env`, leave the host's `SOPS_AGE_KEY` unset, and recreate the service. Keep a recovery copy; never overwrite an identity still needed for decryption.

Exported `SOPS_AGE_KEY` is also passed at container creation, with sudo environment preservation required when applicable. Do not put private keys in `.env`, build arguments, images, or Git. Changing an exported key does not update an existing container. See the logging issue below before using this mode.

## TODO

- Address nerdctl Compose `v2.4.2` logging expanded environment values, including `SOPS_AGE_KEY`, at info level. Environment-key tests passed but exposed the disposable identity in logs. Use the tested mounted-key-file mode for real identities until confidential logging is verified.
- Verify ARM64, the NAS runtime, commented optional clients, and live cluster/authentication/registry/backup workflows. Current verification covers local `linux/amd64` builds and disposable-container checks only.
- Provide a tracked non-secret `.env` example for fresh clones; the current settings file is ignored by Git.
