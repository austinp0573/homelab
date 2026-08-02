# borg

## setup with a TrueNAS SCALE endpoint

create the datasets:

```bash
.
├── coldpool
│   ├── borg
│   │   ├── admin
│   │   │   ├── .bash_history
│   │   │   └── .ssh
│   │   ├── dmz
│   │   │   └── .ssh
│   │   └── lab
│   │       └── .ssh
│   ├── documents
│   ├── media
│   ├── software-isos
│   └── vault
└── fastpool
    ├── bin
    │   ├── borg-server
    │   │   └── borg
    │   └── tree
    │       └── tree
    ├── borg-server-bin
    │   └── tmp
    ├── home
    │   └── austin
    │       ├── .bash_history
    │       ├── .bashrc
    │       └── .ssh
    └── scratch
```

get the borg bin from: [borg-binary](https://github.com/borgbackup/borg/releases/download/1.4.4/borg-linux-glibc231-x86_64)

`sudo wget -o /mnt/fastpool/bin/borg-server/borg https://github.com/borgbackup/borg/releases/download/1.4.4/borg-linux-glibc231-x86_64`

interestingly it can't be run even once you get it because of how **TrueNAS** locks down the file system.

run it with: `sudo TMPDIR=/var/tmp /mnt/fastpool/bin/borg-server/borg`

```bash
truenas% sudo TMPDIR=/var/tmp /mnt/fastpool/bin/borg-server/borg --version
borg 1.4.4
```

create the users for the different scopes:

- admin
- lab
- dmz

need to make sure you create the datasets first so you can assign a home directory to a given user, you have to do that to create a user
only give them ssh/shell access

create the necessary directories/files for them:

```bash
for domain in admin lab dmz; do
    user="borg-${domain}"
    user1="${domain}"
    homedir="/mnt/coldpool/borg/${user1}"
    mkdir -p "${homedir}/.ssh"
    touch "${homedir}/.ssh/authorized_keys"
    chmod 700 "${homedir}/.ssh"
    chmod 600 "${homedir}/.ssh/authorized_keys"
    chown -R "${user}:${user}" "${homedir}/.ssh"
done
```

create the keys for each:

`ssh-keygen -t ed25519 -f <filename> -C <borg-user-ssh-key> -N ""`

add this to the beginning (before the key, but still on one line) to the users authorized_keys entry:

`restrict,command="TMPDIR=/var/tmp /mnt/fastpool/bin/borg-server/borg serve --append-only --restrict-to-path /mnt/coldpool/borg/<localtion>" <ssh-key-contents>`


### Server side checklist

* [ ] borg binary present with proper permissions
* [ ] all desired users created with `~/.ssh/authorized_keys` that have proper permissions and are properly scoped
* [ ] desired users broader permissions are properly configured


&nbsp;

**466f724a616e6574**
