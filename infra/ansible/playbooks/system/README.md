# system playbooks

These playbooks are focused entry points for the existing debian system roles.

## playbooks

- `bootstrap.yml`: first-run bootstrap for hosts in `debian_bootstrap_targets`
- `base.yml`: steady-state base configuration for hosts in `debian_hosts`

The root-level `site.yml`, `playbooks/bootstrap.yml`, and `playbooks/base.yaml` are left in place for compatibility while I reorganize `infra/ansible/`.

