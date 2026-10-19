### Configuration Architecture

```text
                                 [ Client Request ]
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 │                                               │
           (TCP :80 / :443)                                (UDP :443)
                 │                                               │
                 ▼                                               ▼
     ┌──────────────────────┐                        ┌──────────────────────┐
     │ fe_main (TLS 1.2/1.3)│                        │ fe_main (QUIC / H3)  │
     └───────────┬──────────┘                        └───────────┬──────────┘
                 │                                               │
                 └───────────────────────┬───────────────────────┘
                                         │
                          ┌──────────────┼──────────────┐
                          │ (ACL: host)  │ (ACL: host)  │ (Fallback)
                          ▼              ▼              ▼
                     ┌─────────┐    ┌─────────┐    ┌────────────┐
                     │ be_app1 │    │ be_app2 │    │ be_default │
                     └─────────┘    └─────────┘    └────────────┘

[ Stats Listener: TCP :8404 ] ──► (HTTP Basic Auth) ──► HAProxy Dashboard

```

---

### Line-by-Line Technical Breakdown

#### Global Configuration (`global`)

Process-wide settings handling system resource allocation, security contexts, and cryptographic defaults.

* `global`: Marks the start of the process-wide global configuration section.
* `log stdout format raw local0`: Configures logging directly to standard output (`stdout`) using unformatted (`raw`) text under syslog facility `local0`, optimized for container log engines (`nerdctl logs`).
* `stats socket /var/run/haproxy.sock mode 660 level admin expose-fd listeners`: Creates an administrative UNIX socket at `/var/run/haproxy.sock` with read/write permissions for owner/group (`660`), grants full administrative access (`level admin`), and passes file descriptors across process reloads for zero-downtime restarts (`expose-fd listeners`).
* `stats timeout 30s`: Sets an inactivity timeout of 30 seconds on connections established to the administrative UNIX socket.
* `maxconn 10000`: Sets the hard limit for maximum simultaneous TCP connections allowed across the entire HAProxy process.
* `tune.ssl.cachesize 200000`: Expands the SSL session cache to hold up to 200,000 entries in memory, optimizing TLS handshake resumption performance with AWS-LC / BoringSSL.
* `ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305`: Defines the allowed cipher suites for incoming TLS 1.2 connections, prioritizing modern AEAD ciphers.
* `ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256`: Specifies the allowed cipher suites specifically for incoming TLS 1.3 connections.
* `ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets`: Sets the minimum allowed protocol version to TLS 1.2 (disabling SSLv3, TLS 1.0, and TLS 1.1) and disables stateful TLS session tickets to enforce perfect forward secrecy.

---

#### Defaults Configuration (`defaults`)

Default settings inherited by all proxy sections (`frontend`, `backend`, `listen`) unless explicitly overridden.

* `defaults`: Marks the start of the inherited configuration block.
* `log global`: Inherits the logging rules defined in the `global` section (`stdout`).
* `mode http`: Operates at Layer 7 (HTTP mode), allowing deep packet inspection, header modification, and layer-7 routing rules.
* `option httplog`: Enables rich HTTP access logging, recording HTTP status codes, URIs, client IP, SSL details, and timing metrics.
* `option dontlognull`: Prevents logging of empty connections (e.g., automated port probes or TCP health checks) to reduce log bloat.
* `option forwardfor`: Automatically appends the client's real IP address to the `X-Forwarded-For` HTTP header sent to backend servers.
* `option http-server-close`: Closes the backend server connection immediately after processing a response while keeping the frontend client connection alive for keep-alive reuse.
* `retries 3`: Sets the number of connection retry attempts HAProxy will perform against a backend server before flagging it as unavailable.
* `timeout connect 5s`: Maximum allowed duration to establish a TCP connection with a backend server (5 seconds).
* `timeout client 50s`: Maximum allowed client-side inactivity time before the connection is terminated (50 seconds).
* `timeout server 50s`: Maximum allowed backend server-side response inactivity time before the connection is terminated (50 seconds).
* `timeout http-request 10s`: Maximum allowed duration for a client to send complete HTTP request headers (protects against Slowloris attacks).
* `timeout http-keep-alive 10s`: Idle timeout before closing an open HTTP keep-alive connection waiting for a new request.
* `timeout queue 1m`: Maximum duration a request remains queued waiting for an available backend connection slot before returning an HTTP 503 error.
* `errorfile 400 /usr/local/etc/haproxy/errors/400.http`: Defines the path to the custom HTTP response payload returned for HTTP 400 Bad Request errors.
* `errorfile 403 /usr/local/etc/haproxy/errors/403.http`: Defines the payload path for HTTP 403 Forbidden errors.
* `errorfile 408 /usr/local/etc/haproxy/errors/408.http`: Defines the payload path for HTTP 408 Request Timeout errors.
* `errorfile 500 /usr/local/etc/haproxy/errors/500.http`: Defines the payload path for HTTP 500 Internal Server errors.
* `errorfile 502 /usr/local/etc/haproxy/errors/502.http`: Defines the payload path for HTTP 502 Bad Gateway errors.
* `errorfile 503 /usr/local/etc/haproxy/errors/503.http`: Defines the payload path for HTTP 503 Service Unavailable errors.
* `errorfile 504 /usr/local/etc/haproxy/errors/504.http`: Defines the payload path for HTTP 504 Gateway Timeout errors.

---

#### Frontend Configuration (`frontend fe_main`)

Handles incoming network sockets, TLS termination, header adjustments, and request routing.

* `frontend fe_main`: Defines a frontend proxy section named `fe_main`.
* `bind *:80`: Binds an unencrypted HTTP listener on all available interfaces on TCP port 80.
* `bind *:443 ssl crt /etc/haproxy/certs/ alpn h2,http/1.1`: Binds an encrypted HTTPS listener on TCP port 443, terminates TLS using certificates located in `/etc/haproxy/certs/`, and negotiates HTTP/2 (`h2`) or HTTP/1.1 via Application-Layer Protocol Negotiation (ALPN).
* `bind quic4@*:443 ssl crt /etc/haproxy/certs/ alpn h3`: Binds a native HTTP/3 QUIC listener over UDP port 443 (`quic4@`), terminating SSL using AWS-LC and offering ALPN `h3`.
* `http-response set-header Alt-Svc 'h3=":443"; ma=86400'`: Injects an `Alt-Svc` header into outgoing HTTP responses to notify browsers that HTTP/3 is available over UDP port 443 for 86,400 seconds (24 hours).
* `http-request redirect scheme https code 301 if !{ ssl_fc }`: Issues an immediate permanent HTTP 301 redirect to the `https://` scheme if the connection was not established over SSL (`!{ ssl_fc }`).
* `http-request set-header X-Forwarded-Proto https if { ssl_fc }`: Sets the `X-Forwarded-Proto: https` HTTP request header if the client connected via SSL.
* `http-request set-header X-Forwarded-Port %[dst_port]`: Sets the `X-Forwarded-Port` HTTP request header to the exact destination port number the client connected to.
* `acl host_app1 hdr(host) -i app1.example.com`: Defines an Access Control List named `host_app1` that evaluates to `true` if the HTTP `Host` header matches `app1.example.com` (case-insensitive).
* `acl host_app2 hdr(host) -i app2.example.com`: Defines an ACL named `host_app2` that evaluates to `true` if the `Host` header matches `app2.example.com`.
* `use_backend be_app1 if host_app1`: Routes traffic to `be_app1` when the `host_app1` ACL matches.
* `use_backend be_app2 if host_app2`: Routes traffic to `be_app2` when the `host_app2` ACL matches.
* `default_backend be_default`: Directs all requests that fail to match any ACL to the fallback backend `be_default`.

---

#### Backend Configurations (`backend`)

Defines target server pools, load-balancing algorithms, session sticky rules, and health checks.

##### Backend 1: `be_app1`

* `backend be_app1`: Defines a backend server pool named `be_app1`.
* `balance roundrobin`: Distributes incoming requests sequentially across healthy servers in turn.
* `option httpchk GET /health`: Configures active Layer 7 health checks by sending an HTTP `GET` request to `/health`.
* `http-check expect status 200`: Considers a backend node healthy only if it responds with an HTTP status `200 OK`.
* `cookie SERVERID insert indirect nocache`: Enables cookie-based session persistence. Injects a `SERVERID` cookie into client responses, hides it from application servers (`indirect`), and instructs caches not to save it (`nocache`).
* `server app1_node1 10.0.0.10:8080 check cookie app1_node1`: Defines backend node `app1_node1` at IP `10.0.0.10:8080` with active health checking (`check`) and sets its assigned session cookie value to `app1_node1`.
* `server app1_node2 10.0.0.11:8080 check cookie app1_node2`: Defines backend node `app1_node2` at IP `10.0.0.11:8080` with active health checking and cookie assignment `app1_node2`.

##### Backend 2: `be_app2`

* `backend be_app2`: Defines a backend server pool named `be_app2`.
* `balance roundrobin`: Distributes traffic round-robin.
* `option httpchk GET /`: Configures active health checks via HTTP `GET /`.
* `http-check expect status 200..399`: Marks servers healthy if they return any HTTP status code between 200 and 399.
* `server app2_node1 10.0.0.20:8080 check`: Defines backend node `app2_node1` at IP `10.0.0.20:8080` with active health checks enabled.

##### Backend 3: `be_default`

* `backend be_default`: Defines the fallback backend server pool.
* `balance roundrobin`: Distributes traffic round-robin.
* `server default_node 127.0.0.1:8080 check`: Defines a single local fallback server at `127.0.0.1:8080` with health checking.

---

#### Stats Dashboard Configuration (`listen stats`)

Combined frontend and backend definition hosting the built-in management and monitoring dashboard.

* `listen stats`: Opens a dedicated combined proxy section named `stats`.
* `bind *:8404`: Binds the stats service socket to TCP port 8404 on all interfaces.
* `mode http`: Operates in Layer 7 HTTP mode.
* `stats enable`: Activates HAProxy's internal web statistics engine.
* `stats uri /`: Serves the dashboard UI at the root path (`/`).
* `stats refresh 10s`: Configures automatic HTML page refresh every 10 seconds.
* `stats show-legend`: Enables the visual metric legend and status color code documentation on the dashboard interface.
* `stats realm HAProxy\ Statistics`: Sets the realm string shown in the HTTP Basic Authentication browser prompt (space escaped with `\`).
* `stats auth admin:SuperSecretPassword123!`: Grants full administrative interface access to user `admin` with password `SuperSecretPassword123!`.
* `stats auth viewer:ReadAccessOnly456!`: Grants read-only interface access to user `viewer` with password `ReadAccessOnly456!`.

---
