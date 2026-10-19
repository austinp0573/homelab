### Domain Routing Architecture

```text
Client Request (stats.example.com)
       │
       ▼
┌──────────────────────────────────────────────┐
│              frontend fe_main                │
│  - ACL: host_stats (hdr(host) stats.ex.com)  │
└──────────────────────┬───────────────────────┘
                       │ match
                       ▼
┌──────────────────────────────────────────────┐
│               backend be_stats               │
│  - stats enable                              │
│  - stats auth admin:Password123!             │
└──────────────────────────────────────────────┘

```

---

### Implementation Methods

| Approach | Configuration Mechanism | Best Used For |
| --- | --- | --- |
| **Dedicated Stats Backend (Recommended)** | ACL in `fe_main` routes to a `backend be_stats` containing `stats enable`. | Clean separation of stats logic from general application routing. |
| **Direct Frontend Handler** | Uses `http-request use-service stats if <ACL>` directly in `fe_main`. | Single-block configurations without adding additional backend sections. |

---

### Configuration Example (Dedicated Stats Backend)

To map `stats.example.com` to your stats dashboard on port 80/443 without opening a separate port:

```haproxy
frontend fe_main
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/ alpn h2,http/1.1
    bind quic4@*:443 ssl crt /etc/haproxy/certs/ alpn h3

    http-response set-header Alt-Svc 'h3=":443"; ma=86400'
    http-request redirect scheme https code 301 if !{ ssl_fc }

    # --- ACL Definitions ---
    acl host_stats hdr(host) -i stats.example.com
    acl host_app1  hdr(host) -i app1.example.com

    # --- Routing Logic ---
    use_backend be_stats if host_stats
    use_backend be_app1  if host_app1

    default_backend be_default

# =====================================================================
# STATS BACKEND
# =====================================================================
backend be_stats
    mode http
    stats enable
    stats uri /
    stats refresh 10s
    stats show-legend

    # Authentication Configuration
    stats realm HAProxy\ Statistics
    stats auth admin:SuperSecretPassword123!

```

---

### Configuration Example (Direct Frontend Handler)

If you prefer keeping stats entirely within the frontend block without defining a dedicated backend:

```haproxy
frontend fe_main
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/ alpn h2,http/1.1

    # Define Stats ACL and Service Engine
    acl host_stats hdr(host) -i stats.example.com
    
    stats enable
    stats uri /
    stats realm HAProxy\ Statistics
    stats auth admin:SuperSecretPassword123!
    
    # Intercept request and serve stats engine if ACL matches
    http-request use-service stats if host_stats

    # Standard Application Routing
    default_backend be_default
```