**Yes, absolutely.** Caddy's `reverse_proxy` directive has native support for both **Active** and **Passive** health checks for upstream backends.

---

### 1. Active Health Checks (Periodic Probing)
Caddy periodically sends HTTP requests to a health endpoint (e.g. `/healthz` or `/ping`) and automatically removes unhealthy backends from rotation:

```caddy
app.example.com {
    reverse_proxy 10.0.0.10:8080 10.0.0.11:8080 {
        # Active Health Check Config
        health_uri /healthz
        health_interval 10s
        health_timeout 3s
        health_status 200
    }
}
```

---

### 2. Passive Health Checks (Monitoring Real Traffic)
Caddy monitors real client requests as they happen. If a backend fails a set number of times (`max_fails`), Caddy marks it unhealthy and temporarily stops sending traffic to it for `fail_duration`:

```caddy
app.example.com {
    reverse_proxy 10.0.0.10:8080 10.0.0.11:8080 {
        # Passive Health Check Config
        fail_duration 30s
        max_fails 3
        unhealthy_status 5xx
    }
}
```

---

### 3. Combining Active + Passive (HAProxy Style)
You can combine both for maximum reliability:

```caddy
app.example.com {
    reverse_proxy 10.0.0.10:8080 10.0.0.11:8080 {
        # Passive (reacts instantly to live failures)
        fail_duration 1m
        max_fails 2

        # Active (probing to verify when backend recovers)
        health_uri /health
        health_interval 15s
        health_timeout 5s
    }
}
```




