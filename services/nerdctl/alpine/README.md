# install nerdctl on alpine linux

- Using github releases is superfluous, the alpine packages are very new.

```bash
apk update
apk add nerdctl buildkit
```

> Probably should take the time to figure out how to transition things to nftables (instead of the included iptables)

---

File Path: `/etc/buildkit/buildkitd.toml`

```toml
[worker.oci]
  enabled = false

[worker.containerd]
  enabled = true
  namespace = "default"
```

---

```bash
rc-update add containerd default
rc-update add buildkitd default
rc-service containerd start
rc-service buildkitd start
```

