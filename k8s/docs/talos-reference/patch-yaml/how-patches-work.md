

I’ll check how Talos distinguishes configuration documents from patches, since that determines which examples can be combined with `---`.

**Both arrangements work, with one distinction: `---` separates documents; it does not merge them.**

1. **Inside `controlplane.yaml` or `worker.yaml`:** additional, complete configuration documents can follow the existing documents, separated by `---`. If that document already exists, edit it rather than appending another copy.

2. **In a separate patch file:** multiple configuration documents can likewise be separated by `---`. Pass that file explicitly to Talos’s patching command. Matching documents are merged into the base configuration; new documents are appended. [Patching documentation](https://docs.siderolabs.com/talos/v1.14/configure-your-talos-cluster/system-configuration/patching)

For example, a separate `customizations.yaml` could contain:

```yaml
apiVersion: v1alpha1
kind: ResolverConfig
nameservers:
    - address: 1.1.1.1
---
apiVersion: v1alpha1
kind: TimeSyncConfig
ntp:
    servers:
        - time.cloudflare.com
```

Merge it into your existing configuration locally:

```bash
talosctl machineconfig patch controlplane.yaml \
    --patch @customizations.yaml \
    --output controlplane-final.yaml
```

That writes a complete configuration file without contacting a node. The same operation works with `worker.yaml`.

You can also keep patches in individual files:

```bash
talosctl machineconfig patch controlplane.yaml \
    --patch @network.yaml \
    --patch @storage.yaml \
    --output controlplane-final.yaml
```

The important rules are:

- **Document identities must be unique within a file.** Identity is `(apiVersion, kind, name)` for named documents, or `(apiVersion, kind)` for unnamed documents. Two `LinkConfig` documents with different interface names are allowed; two unnamed `ResolverConfig` documents are duplicates.
- **Legacy `machine:` and `cluster:` fragments require merging.** Appending them after `---` would create another legacy configuration document. Put their fields into the existing document, or apply them through the patch command.
- **A directory of separate files is not loaded automatically.** Supply the files explicitly, or combine the selected documents into one patch file.
- **Merge behavior matters.** Many lists append during strategic merging; some fields replace or merge by identifying keys. Repeated patch files are processed in command-line order. [Merge rules](https://docs.siderolabs.com/talos/v1.14/configure-your-talos-cluster/system-configuration/patching)

For the extracted examples, select and adapt the desired variants before combining them. The fragment examples exported with `--all` may require their surrounding structure.









---






I’ll check how Talos handles patches before and after the initial machine configuration, and whether a later full configuration preserves earlier changes.

Applying the base configuration first and patching the running node later is supported. A later `apply-config` replaces the configuration, so it can remove changes made by earlier live patches. I’m checking the maintenance-mode exception to distinguish that from submitting patches before any base configuration exists.

**You can submit `controlplane.yaml` first and apply patches later. You do not need to merge everything into a local file beforehand.**

The order matters:

| Sequence | Result |
|---|---|
| Apply base configuration, then patch | Supported. Patches modify the node’s current configuration. |
| Submit patches before any configuration exists | There is no existing configuration to patch; Talos does not queue them for a future base configuration. |
| Patch an existing configuration, then apply `controlplane.yaml` | The submitted file replaces the configuration. Earlier patch changes disappear unless included in that submission. |

`patch machineconfig` reads the current configuration, merges the patch, and submits the resulting configuration back to the node. [Talos documentation](https://docs.siderolabs.com/talos/v1.14/configure-your-talos-cluster/system-configuration/editing-machine-configuration)

For example, initially configure an unconfigured node:

```bash
talosctl apply-config \
    --insecure \
    --nodes <NODE_IP> \
    --file controlplane.yaml
```

After its authenticated API becomes available, apply additional changes:

```bash
talosctl \
    --talosconfig ./talosconfig \
    --endpoints <NODE_IP> \
    --nodes <NODE_IP> \
    patch machineconfig \
    --patch @customizations.yaml
```

Alternatively, **submit the base and separate patches together**, without creating an intermediate file:

```bash
talosctl apply-config \
    --insecure \
    --nodes <NODE_IP> \
    --file controlplane.yaml \
    --config-patch @customizations.yaml
```

Here, `talosctl` merges the patches into the local file’s contents before sending the result. This behavior is explicit in the [command implementation](/home/austin/scratch/talos/cmd/talosctl/cmd/talos/apply-config.go:74).

Two qualifications matter:

- **Live patches do not update your local `controlplane.yaml`.** Preserve the patch files and include their changes whenever you subsequently submit a full configuration.
- Installation settings and connectivity required during provisioning should be present in the initial submission. Changing installation settings afterward does not redo the installation.

The v1.15 checkout also permits partial configurations during maintenance mode. That is applying a partial configuration, rather than queuing patches; a later full `apply-config` still replaces it. [Server implementation](/home/austin/scratch/talos/internal/app/machined/internal/server/v1alpha1/v1alpha1_server.go:204)


