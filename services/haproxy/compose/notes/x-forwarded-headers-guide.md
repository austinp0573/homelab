# Reverse Proxy HTTP Forwarded Headers Guide

## 1. Overview & The Problem Statement

When a client directly connects to a backend web server, the web server sees the client's actual IP address and connection details on the TCP layer.

However, when a **Reverse Proxy** (such as HAProxy, Nginx, or Caddy) sits between the client and the backend:

```
[ Client: 203.0.113.45 ] 
          │ 
          ▼ (Connects via HTTPS to public IP)
[ HAProxy: 198.51.100.1 ] 
          │ 
          ▼ (Proxies internal HTTP request)
[ Backend (e.g., ntfy / Gatus): 127.0.0.1 ]
```

From the backend server's perspective:
- The TCP socket source IP is `127.0.0.1` (HAProxy's IP), **not** `203.0.113.45`.
- The connection protocol is plain `http` (if HAProxy terminated TLS), **not** `https`.
- The destination port is the internal container port (e.g., `8080`), **not** `443`.

Without special HTTP request headers, backend application servers cannot perform IP rate-limiting, geo-location logging, audit security, or build correct `https://` redirect links.

---

## 2. Comprehensive Header Breakdown

### `X-Forwarded-For` (XFF)

* **What it means**: "Here is the chain of client IP addresses that this request passed through."
* **Format**: Comma-separated list of IP addresses.
  ```http
  X-Forwarded-For: 203.0.113.45, 198.51.100.1
  ```
* **Purpose**: Identifies the originating IP address of a client connecting to a web server through a proxy.
* **How it works**:
  - The client IP (`203.0.113.45`) is placed first.
  - As the request passes through additional proxy hops, each proxy appends the IP address of the incoming connection it received.
* **When to use**:
  - In virtually **all reverse proxy setups**.
  - Essential for backend IP logging, rate-limiting, and geo-IP lookup.
* **Critical Security Warning (IP Spoofing)**:
  - An external attacker can send a fake header like `X-Forwarded-For: 1.2.3.4`.
  - Your edge proxy **MUST sanitize or overwrite** the header (e.g., using `option forwardfor` in HAProxy) so client-supplied values cannot trick backends or bypass ACLs/rate limits.

---

### `X-Forwarded-Proto` (XFP)

* **What it means**: "Here is the original protocol protocol scheme used by the client to connect to the edge proxy."
* **Format**: Single string value, either `http` or `https`.
  ```http
  X-Forwarded-Proto: https
  ```
* **Purpose**: Informs backends whether the incoming client connection was encrypted (HTTPS) or unencrypted (HTTP) before SSL/TLS termination at the proxy.
* **When to use**:
  - Whenever your proxy terminates SSL/TLS and passes unencrypted HTTP traffic to the backend.
  - Backends use this to:
    - Generate correct `https://` URLs for redirects, attachment downloads, or OAuth callbacks.
    - Set the `Secure` flag on HTTP cookies.
    - Prevent infinite HTTP -> HTTPS redirect loops.

---

### `X-Forwarded-Host`

* **What it means**: "Here is the original `Host` HTTP request header sent by the client."
* **Format**: Single hostname (and optional port).
  ```http
  X-Forwarded-Host: vault.app.tusko.org
  ```
* **Purpose**: Preserves the original requested domain name if the proxy rewrites or overrides the internal `Host` header sent to backend containers.
* **When to use**:
  - Multi-tenant applications or reverse proxies that forward requests to internal backends listening on generic hostnames/IPs.
  - Backends that need to render absolute canonical links or validate CSRF `Origin`/`Host` headers based on the public domain.

---

### `X-Forwarded-Port`

* **What it means**: "Here is the destination port used by the client when connecting to the edge proxy."
* **Format**: Single integer port number (e.g., `443`, `80`, `8443`).
  ```http
  X-Forwarded-Port: 443
  ```
* **Purpose**: Informs the backend of the external port that handled the client's request.
* **When to use**:
  - When non-standard HTTPS/HTTP ports are used at the edge (e.g., public port `8443` proxied to internal container port `8080`), ensuring generated links include the correct public port.

---

### `X-Real-IP`

* **What it means**: "Here is strictly the single, immediate client IP address."
* **Format**: Single IP address (non-comma-separated).
  ```http
  X-Real-IP: 203.0.113.45
  ```
* **Purpose**: A non-standard alternative pioneered by Nginx. Unlike `X-Forwarded-For` (which builds a chain list), `X-Real-IP` holds only the single client IP.
* **When to use**:
  - When backend microservices (or specific application frameworks like Gunicorn or legacy Python apps) specifically look for `X-Real-IP` instead of parsing `X-Forwarded-For`.

---

### `Forwarded` (RFC 7239 Standard)

* **What it means**: The standardized IETF replacement for all `X-Forwarded-*` headers.
* **Format**: Key-value parameters separated by semicolons.
  ```http
  Forwarded: for=203.0.113.45;proto=https;by=198.51.100.1;host=vault.app.tusko.org
  ```
* **Purpose**: Combines IP (`for`), protocol (`proto`), proxy IP (`by`), and host (`host`) into a single RFC-compliant header.
* **When to use**:
  - Modern applications that support RFC 7239 standard parsing. *(Note: Many popular frameworks and containers like `ntfy` or `gatus` still prioritize `X-Forwarded-For` / `X-Forwarded-Proto` for compatibility).*

---

## 3. Quick Reference Matrix

| Header | Example Value | Primary Use Case | Required in Edge HAProxy? |
| :--- | :--- | :--- | :--- |
| **`X-Forwarded-For`** | `203.0.113.45` | Real Client IP, Rate Limiting, Audit Logs | **Yes** (`option forwardfor`) |
| **`X-Forwarded-Proto`** | `https` | HTTPS Detection, Secure Cookie Flags, Redirects | **Yes** (set if SSL) |
| **`X-Forwarded-Host`** | `ntfy.admin.tusko.org` | Virtual Host preservation | Recommended |
| **`X-Forwarded-Port`** | `443` | Non-standard port redirect building | Optional / As needed |
| **`X-Real-IP`** | `203.0.113.45` | Alternative single IP header for Nginx/Python backends | Optional |
| **`Forwarded`** | `for=203.0.113.45;proto=https` | RFC 7239 Standardized specification | Optional |

---

## 4. How to Configure in HAProxy (`haproxy.cfg`)

Below is the standard configuration snippet for HAProxy to manage forwarded headers safely:

```haproxy
frontend https_front
    bind *:443 ssl crt /etc/haproxy/certs/
    mode http

    # 1. Automatically manage X-Forwarded-For (creates header or appends client IP)
    option forwardfor

    # 2. Sanitize and set X-Forwarded-Proto
    http-request del-header X-Forwarded-Proto
    http-request set-header X-Forwarded-Proto https if { ssl_fc }
    http-request set-header X-Forwarded-Proto http if !{ ssl_fc }

    # 3. Preserve original client host and port
    http-request set-header X-Forwarded-Host %[req.hdr(Host)]
    http-request set-header X-Forwarded-Port %[dst_port]

    # 4. Optional: Set X-Real-IP for backends expecting single IP
    http-request set-header X-Real-IP %[src]

    default_backend ntfy_backend

backend ntfy_backend
    mode http
    server ntfy_1 127.0.0.1:8080 check
```
