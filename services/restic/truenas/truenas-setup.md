# truenas setup for restic

## prune

rest-server is append-only, so clients cannot forget/prune.

run `prune.sh` on the nas against the dataset path (local mount, not the rest: url):

```sh
REPO_PATH=/mnt/coldpool/restic/admin/sample-host \
PASSWORD_FILE=/root/restic-password.txt \
./prune.sh
```

`prune.sh` runs a repository check before `forget --prune`. The default check
reads 5 percent of repository data.

Set up these commands in the TrueNAS Cron Jobs UI.

weekly sample check and prune:

```cron
0 4 * * 0 root REPO_PATH=/mnt/coldpool/restic/admin/sample-host PASSWORD_FILE=/root/restic-password.txt /path/to/prune.sh >> /var/log/restic-maintenance.log 2>&1
```

monthly full check and prune:

```cron
0 4 1 * * root CHECK_ARGS= REPO_PATH=/mnt/coldpool/restic/admin/sample-host PASSWORD_FILE=/root/restic-password.txt /path/to/prune.sh >> /var/log/restic-maintenance.log 2>&1
```

`forget` selects snapshots outside the retention policy. `prune` removes their
unreferenced data. Only run both from TrueNAS or another host with direct write
access to the repository.

## datasets

```bash
coldpool
├── documents       0.5
├── media           1
├── restic          11
│   ├── admin       7
│   └── dmz         4
├── software-isos   1
└── vault           0.5
```

* `1M` block size for `restic/`

---

`apps` -> `discover apps` -> `Restic REST server`

## backup users configuration

* Application name
    - restic-rest-server - Unique lowercase identifier for the application instance.
* Version
    - 1.1.6 - Pre-selected stable application package version.
* Timezone
    - Etc/UTC - Standardizes logging timestamps and prevents daylight savings desynchronization.
* Append Only
    - Checked - Enforces ransomware protection by blocking data deletions from the client.
* Group Accessible Repositories
    - Unchecked - Restricts target data access strictly to the authenticated creator user.
* Private Repositories
    - Checked - Mandates explicit user credential verification for all network connections.
* No Authentication
    - Unchecked - Hardens perimeter security by forcing user password validation checks.
* Proxy Authentication Username
    - Leave Blank - Only utilized when deploying behind an external validating reverse proxy.
* Basic Auth Users
    - Add custom username and secure password - Creates the access credentials for the client container.
* Extra Options 
    - Leave Blank - Unnecessary for basic standalone production deployment instances.
* Additional Environment Variables 
    - Leave Blank - Custom container system parameters are not required.
* User ID 
    - 568 - Default TrueNAS apps system user for proper security context execution.
* Group ID
    - 568 - Default TrueNAS apps system group for unified ZFS storage permissions.
* Port Number 
    - 8000 - Assigns the standard default network listening port for the REST API interface.
* Host IPs
    - Leave Blank - Configures the server to listen on all available system interfaces.
* Networks
    - Leave Blank - Standard internal container bridge network mapping is sufficient.
* Host Network 
    - Unchecked - Isolates container networking from the core TrueNAS host network space.
* Certificate 
    - 'truenas_default' Certificate
        - **need to add:** copy the TrueNAS cert's public key/cert file to each client and pass it via `--cacert /path/to/cert.pem` (or set `RESTIC_CACERT`) 
* Storage Configuration:    
    * Data StorageType 
        - Host Path - Links the application backend straight to a persistent local ZFS dataset.
    * Enable ACL 
        - Checked - Maintains proper OpenZFS access control list inheritance rules on backup chunks.
    * Host Path *
        * `/mnt/coldpool/restic`
    * ACL Entries
        * Blank
    * ACL Options
        * CHECK - Force Flag
* Additional Storage 
    - Leave Blank - No secondary storage pools or external volumes are required.
* Labels Configuration 
    - Leave Blank - Optional metadata organization tags are completely unnecessary.
* LimitsCPUs 
    - 2
        - Only streaming data to disk, all of the **encryption, compression, ect** happens on the client
* Memory (in MB) 
    - 1024
        - 1GB is plenty
