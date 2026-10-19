### Raw HTTP File Structure

HAProxy error files are **not standard HTML files**. Because HAProxy returns these files directly to the socket during low-level engine errors, each file must contain a raw HTTP response dump: an **HTTP status line**, **HTTP headers**, a **blank line separator**, and the **HTML body payload**.

```text
┌─────────────────────────────────────────┐
│ HTTP/1.0 503 Service Unavailable        │ ◄── Status Line
│ Cache-Control: no-cache                 │
│ Connection: close                       │ ◄── HTTP Headers
│ Content-Type: text/html                 │
├─────────────────────────────────────────┤
│ [BLANK LINE]                            │ ◄── Required Header/Body Separator
├─────────────────────────────────────────┤
│ <!DOCTYPE html>                         │
│ <html>                                  │ ◄── Body Payload (HTML/JSON/Text)
│   ...                                   │
│ </html>                                 │
└─────────────────────────────────────────┘

```

---

### Template Examples

#### 1. Bad Request (`400.http`)

```http
HTTP/1.0 400 Bad Request
Cache-Control: no-cache
Connection: close
Content-Type: text/html

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>400 Bad Request</title>
    <style>
        body { font-family: system-ui, sans-serif; background: #0f172a; color: #f8fafc; display: flex; height: 100vh; align-items: center; justify-content: center; margin: 0; }
        .card { background: #1e293b; padding: 2rem; border-radius: 0.5rem; border: 1px solid #334155; text-align: center; max-width: 400px; }
        h1 { color: #f43f5e; margin-top: 0; }
    </style>
</head>
<body>
    <div class="card">
        <h1>400 - Bad Request</h1>
        <p>The server could not understand the request due to invalid syntax.</p>
    </div>
</body>
</html>

```

#### 2. Service Unavailable (`503.http`)

```http
HTTP/1.0 503 Service Unavailable
Cache-Control: no-cache
Connection: close
Content-Type: text/html

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>503 Service Unavailable</title>
    <style>
        body { font-family: system-ui, sans-serif; background: #0f172a; color: #f8fafc; display: flex; height: 100vh; align-items: center; justify-content: center; margin: 0; }
        .card { background: #1e293b; padding: 2rem; border-radius: 0.5rem; border: 1px solid #334155; text-align: center; max-width: 400px; }
        h1 { color: #fbbf24; margin-top: 0; }
    </style>
</head>
<body>
    <div class="card">
        <h1>503 - Service Unavailable</h1>
        <p>No backend servers are available to handle this request.</p>
    </div>
</body>
</html>

```

---

### Implementation Strategies

| Strategy | Execution Method | Primary Advantage |
| --- | --- | --- |
| **1. Built-in Container Defaults** | Omit custom files; default image files exist automatically at `/usr/local/etc/haproxy/errors/`. | Zero file management required. |
| **2. Host Directory Volume Mount** | Create an `./errors/` directory on host with custom `.http` files and bind mount into container. | Full control over HTML styling, branding, and status text. |
| **3. Modern Inline Rules (HAProxy 2.2+)** | Remove `errorfile` lines and use `http-errors` or `http-request return` directly in `haproxy.cfg`. | Eliminates external file dependencies entirely. |

---

### Deployment via Host Volume Mount

To inject custom error pages into your `nerdctl` container without modifying the image:

```text
Host Directory Layout
├── haproxy.cfg
└── errors/
    ├── 400.http
    ├── 403.http
    ├── 408.http
    ├── 500.http
    ├── 502.http
    ├── 503.http
    └── 504.http

```

Mount both the configuration file and the custom errors folder when starting the container:

```bash
nerdctl run -d \
  --name haproxy \
  --network host \
  -v $(pwd)/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
  -v $(pwd)/errors:/usr/local/etc/haproxy/errors:ro \
  haproxytech/haproxy:alpine-3.4

```

---

### Alternative: Modern Inline Configuration (No External Files)

If you prefer to keep your deployment strictly contained within `haproxy.cfg` without managing an `./errors/` folder, you can replace the `errorfile` lines in `defaults` with an `http-errors` block:

```haproxy
# Define inline custom error responses inside haproxy.cfg
http-errors custom-errors
    errorfile 400 inline "HTTP/1.0 400 Bad Request\r\nContent-Type: text/plain\r\n\r\nBad Request\n"
    errorfile 503 inline "HTTP/1.0 503 Service Unavailable\r\nContent-Type: text/plain\r\n\r\nService Unavailable\n"

defaults
    log global
    mode http
    # Apply errorfiles group globally
    errorfiles custom-errors
```