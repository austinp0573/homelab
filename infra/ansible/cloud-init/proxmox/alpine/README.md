# alpine proxmox nocloud

Examples for first-boot Alpine VM bootstrap on Proxmox.

Cloud-init should do only enough work to make the VM reachable and manageable:

- create the initial Ansible user
- install Python for Ansible
- install and start Dropbear for SSH
- install and start the qemu guest agent
- keep SSH key auth working

After first boot, run the following to initiate the playbook for the the proxmox alpine VM.

```sh
ansible-playbook playbooks/proxmox/alpine_vm.yml
```

The Ansible playbook owns the steady state after that point.

## files

- `user-data.example.yml`: minimal first-boot package, user, SSH, and service bootstrap
- `meta-data.example.yml`: placeholder instance metadata
- `network-config.example.yml`: optional static network example

- Copy these into Proxmox snippets storage as needed and replace placeholder values locally.
- Don't commit things that shouldn't be committed.
