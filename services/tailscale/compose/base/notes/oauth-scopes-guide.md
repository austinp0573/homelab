# Tailscale OAuth Credential Scopes Reference

This document explains the settings and scope options available when creating a new OAuth client credential in the Tailscale admin console, along with recommendations for container workloads.

## 1. General Settings

### Description
A human-readable label identifying what uses this credential (example: `homelab-container-autodeploy`).

### Tags
The tags assigned to devices registered using this OAuth client.
- Significance: Every device created by an OAuth client must be owned by a tag, not a user.
- Recommendation: Select the tag corresponding to your workload (example: `tag:container` or `tag:vps-router`).

---

## 2. Recommended Configuration for Containers

For node registration and automated container startup, apply the Principle of Least Privilege:

- Tags: Select your target tag (example: `tag:container`)
- Devices -> Core: Set to `Write` (or `Read & Write`)
- All other scopes: Leave unchecked / None

This allows the container to register itself on your Tailnet under the specified tag, but prevents the credential from modifying your Tailnet configuration, users, DNS, or policies if compromised.

---

## 3. Scopes Breakdown and Significance

### General

#### DNS
- Options: None, Read, Write
- Purpose: Read or modify Tailnet DNS settings, MagicDNS, and search domains.
- Significance: Unnecessary for container node registration. Granting Write allows changing DNS routing for the entire Tailnet.

#### Policy File
- Options: None, Read, Write
- Purpose: Read or edit ACL policy rules (huJSON).
- Significance: High risk. Granting Write allows an attacker to rewrite firewall rules and gain access to all machines.

#### Users
- Options: None, Read, Write
- Purpose: Manage user roles, approve, suspend, or delete users.
- Significance: Administrative access. Never grant to automated container keys.

#### Tailnets
- Options: None, Read, Write
- Purpose: Read or create Tailnets via API.
- Significance: Used for multi-tenant SaaS management. Unnecessary for homelab containers.

#### Services
- Options: None, Read, Write
- Purpose: Manage Tailscale Services and properties.
- Significance: Controls service discovery and advertising. Unnecessary for basic node startup.

#### OAuth applications
- Options: None, Read, Write
- Purpose: Manage other OAuth applications in the Tailnet.
- Significance: High risk. Allows creating additional credentials.

---

### Devices

#### Core (REQUIRED FOR CONTAINER BOOT)
- Options: None, Read, Write
- Purpose: Register new devices, update device properties, or delete devices.
- Significance: Required. Set to `Write` so containerboot can register the container as a new device on startup.

#### Posture Attributes
- Options: None, Read, Write
- Purpose: Set device posture attributes for posture-based access control.
- Significance: Only needed if using Tailscale Enterprise posture checks.

#### Routes
- Options: None, Read, Write
- Purpose: Approve or reject subnet routes advertised by devices.
- Significance: Controls subnet route approval. Usually approved in the admin console or via ACL auto-approvers rather than by the node key.

#### Device Invites
- Options: None, Read, Write
- Purpose: Generate device invitation links.
- Significance: Unnecessary for container node authentication.

---

### Keys

#### API Access Tokens
- Options: None, Read, Write
- Purpose: Generate personal API tokens.
- Significance: High risk. Allows creating administrative API tokens.

#### Auth Keys
- Options: None, Read, Write
- Purpose: Generate pre-authenticated auth keys via API.
- Significance: Allows generating auth keys. Unnecessary if using OAuth directly.

#### OAuth Keys
- Options: None, Read, Write
- Purpose: Generate other OAuth client credentials.
- Significance: High risk administrative permission.

#### Federated Keys
- Options: None, Read, Write
- Purpose: Manage federated identities and keys.
- Significance: Advanced identity integration. Unnecessary for containers.

---

### Webhooks
- Options: None, Read, Write
- Purpose: Configure event webhooks for Tailnet events.
- Significance: Used for event integration scripts, not container registration.

---

### Logging

#### Log Streaming
- Options: None, Read, Write
- Purpose: Configure SIEM / log streaming integrations.
- Significance: Security operations feature. Unnecessary for containers.

#### Audit Logs
- Options: None, Read
- Purpose: Read administrative action audit logs.
- Significance: Audit reporting. Unnecessary for containers.

---

### Settings

#### Account Settings
- Options: None, Read, Write
- Purpose: Read or modify Tailnet contact details and billing info.
- Significance: Administrative account settings.

#### Feature Settings
- Options: None, Read, Write
- Purpose: Enable or disable Tailnet feature flags.
- Significance: Global Tailnet configuration.

#### Networking Settings
- Options: None, Read, Write
- Purpose: Manage global networking settings like HTTPS certificates or MagicDNS toggle.
- Significance: Global networking configuration.
