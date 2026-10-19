### Hitless Socket-Passing Architecture

```text
Hitless Reload Sequence via UNIX Domain Socket

Old Process (Worker A)                                 New Process (Worker B)
 [ Holds Listening FDs ]                                   [ Spawns & Parses ]
 [ Ports :80, :443, :8404 ]                                [ New haproxy.cfg ]
          │                                                        │
          │──────────── Connects to UNIX Socket ──────────────────►│
          │          (/var/run/haproxy.sock)                       │
          │                                                        │
          │ ── Sends Listening Socket FDs (SCM_RIGHTS) ───────────►│ ── Binds to Existing FDs
          │                                                        │    (No EADDRINUSE Error)
          │                                                        │
     [ Stops Accepting ]                                      [ Begins Accepting ]
     [ New Connections ]                                      [ New Connections ]
          │                                                        │
          ▼                                                        ▼
   [ Drains In-Flight ]                                    [ Fully Operational ]
   [   Connections    ]                                            │
          │                                                        │
          ▼                                                        │
      [ Exits ] ───────────────────────────────────────────────────┘

```

---

### How `expose-fd listeners` Works Under the Hood

When a process binds to a network port (e.g., TCP `80` or `443`), the Linux kernel assigns it a **File Descriptor (FD)**. Normally, if a new process attempts to bind to an already occupied port, the OS kernel rejects it with `EADDRINUSE` (Address already in use).

The `expose-fd listeners` directive enables HAProxy's **zero-downtime hitless reload** mechanism by transferring these listening file descriptors directly between processes over the UNIX socket.

#### The Reload Step-by-Step Sequence

1. **Triggering the Reload:** You send a reload signal (e.g., `haproxy -sf <PID>` or `kill -USR2 <master_pid>`) inside or to the container.
2. **Spawning the New Process:** HAProxy starts a new worker process while the old worker process is still active and handling live traffic.
3. **Connecting to the Runtime Socket:** Instead of calling the system `bind()` function to request new ports from the OS kernel, the new process opens `/var/run/haproxy.sock`.
4. **FD Transfer via `SCM_RIGHTS`:** The old HAProxy process uses Linux IPC (Inter-Process Communication) ancillary messages (`SCM_RIGHTS`) to send its exact, open listening file descriptors over `/var/run/haproxy.sock` to the new process.
5. **Seamless Handover:** The new process adopts these file descriptors instantly. Because the sockets were never closed by the kernel, incoming SYN packets waiting in the OS network queue are never dropped, and no connection reset (`RST`) errors occur.
6. **Graceful Drain:** The old HAProxy process stops accepting new connections, allows existing active HTTP/TCP sessions to complete, and then terminates cleanly.

---

### Reload Mechanism Comparison

| Metric / Mechanism | Standard Service Restart | Legacy HAProxy Reload | Hitless Socket Reload (`expose-fd listeners`) |
| --- | --- | --- | --- |
| **Port Binding Strategy** | Closes socket, then re-binds. | Uses `SO_REUSEPORT` kernel flag. | Passes exact socket FDs via UNIX socket (`SCM_RIGHTS`). |
| **Packet Loss Window** | Drops packets during gap (Refused/Reset). | Potential packet drop under heavy SYN bursts during OS race conditions. | **Zero packet loss.** Network queue remains continuously open. |
| **Active Connections** | Severed immediately. | Drained gracefully. | Drained gracefully. |
| **Container Impact** | Kills and recreates container instance. | Preserves container instance. | Preserves container instance. |

---

### Executing a Hitless Reload in Containerized Environments

To trigger this process inside your `nerdctl` container without restarting or recreating the container instance:

```bash
# Reload HAProxy configuration seamlessly inside a running container
# first line is just checking to make sure you don't load into a broken configuration file
nerdctl exec -it haproxy_container haproxy -f /usr/local/etc/haproxy/haproxy.cfg -c && \
nerdctl exec -it haproxy_container kill -USR2 1
```

Obviously if you're feeling gutsy you can just skip the check, probably not a good idea though.

`USR2` is one of Unix's standard signals — specifically **SIGUSR2** (signal number 12), a "user-defined" signal reserved for applications to use however they want (unlike `SIGKILL` or `SIGTERM`, which have fixed system meanings).

Programs can attach custom behavior to it. HAProxy's master process listens for `SIGUSR2` and, on receipt, triggers its reload sequence (re-exec + reload config + spawn new worker).

Other examples of "reserved but app-defined" signals: `SIGUSR1`, `SIGHUP` (often used for reload in other daemons, like nginx).

The `-` before it is just shell syntax for `kill`'s `-<signal>` argument — same idea as `-9` for SIGKILL or `-1` for SIGHUP.
