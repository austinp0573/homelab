# bootstrap

Bootstraps Debian-family hosts for Ansible management.

## scope

- installs `sudo`
- creates the `ansible` and `austin` users
- installs SSH authorized keys for both users
- grants passwordless sudo to the `ansible` user
- writes basic OpenSSH hardening for key-based access

## required variables

- `austin_user_password`: password used when creating the `austin` account. keep this in vault or ignored vars.
- `ansible_user_ssh_pub_key`: public key for the `ansible` management user.
- `austin_user_ssh_pub_key`: public key for the `austin` user.

## notes

This role is for Debian-family hosts and still reflects the original homelab bootstrap path. Alpine hosts should use the Alpine playbooks and roles instead.
