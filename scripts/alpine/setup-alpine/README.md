## alpine autoinstall

this project automates alpine linux installations inside proxmox vms using a custom configuration iso sidecar

### contents

- `attach-answerfile.sh.template`
    - host script that builds the iso and attaches it to a vm
    - installs desireable packages
    - gets host ready to use
- `alpine-answerfile.cfg.template` 
    - answerfile configuration template for `setup-alpine`
    - **READ `.env.example` CAREFULLY**
        - Certain values will cause the automated `setup-alpine` to fail
        - I made a "NOTE" for such values
            - (At least the ones I encountered)
- `helper-script.sh`
    - applies all the values from ./.env where they need to go
    - makes `attach-answerfile.sh` executable
    - packages things for transport
    - cleans up
- `.env.example`
    - Copy this to .env and populate with your values
- `.envsubst-vars`
    - A file so I could explicitly declare the vars to use to `envsubst`

### prerequisites

- proxmox host root access
- vanilla alpine linux virtual iso downloaded to local storage
    - Tested using [Alpine Virt 3.24.1](https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-virt-3.24.1-x86_64.iso)
- Create a regular **Alpine** VM in proxmox with the ISO
    - **MAKE SURE** to either use `VirtIO Block` or change the `DISKOPTS` variable accordingly

### usage

1. `cp .env.example .env`
2. Fill in all the values.
    - I have notes for areas I found would break things in testing.
3. Run `./helper-script.sh`
4. Read the directions output by `./helper-script.sh`
    - `scp` the files to pve host
    - extract the `tar`
    - change into the directory and run `attach-answerfile.sh`

5. Start the VM
6. In the `Console`:
    - **login:** as `root`
    - Then run the following:
        - Profit?

```bash
mkdir -p /tmp/cfg && mount -t iso9660 /dev/sr1 /tmp/cfg && /tmp/cfg/automated-install.sh
```

7. It will reboot on it's own. `ssh` in with the key you populated (or the password)
8. As `root` (though the user you setup has a password and is added to wheel)
    - `/root/run-scripts.sh`
