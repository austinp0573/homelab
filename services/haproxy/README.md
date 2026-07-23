# haproxy

* [https://www.haproxy.com/downloads](https://www.haproxy.com/downloads) to setup the haproxy performance repo

* the commands (that might change, use the above link as the canonical source of truth):

```bash
# Create a directory for the key if it doesn't exist
sudo install -d -m 0755 /usr/share/keyrings
# Download the GPG key
sudo wget -qO /usr/share/keyrings/HAPROXY-key-community.asc https://pks.haproxy.com/linux/community/RPM-GPG-KEY-HAProxy

# Add the HAProxy repository for trixie and HAProxy 3.4
echo "deb [signed-by=/usr/share/keyrings/HAPROXY-key-community.asc] https://www.haproxy.com/download/haproxy/performance/debian/ha34 trixie main" | sudo tee /etc/apt/sources.list.d/haproxy.list

sudo apt-get update
sudo apt-get install haproxy-awslc
```

the package comes with a `systemd` service, enable it:

```bash
sudo systemctl enable --now haproxy
sudo systemctl status haproxy
```

## config

* setting `maxconn 4096` reduces RAM 85 -> 45.

```bash
global
    stuff
    stuff

    # limit max connections
    maxconn 4096
```

> NOTE: the alpine-3.4 image DOES have the AWS-LC crypto enabled


&nbsp;

**466f724a616e6574**