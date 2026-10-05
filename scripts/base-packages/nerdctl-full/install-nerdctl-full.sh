#!/bin/sh

set -eu

install_dependencies() {
    if command -v curl >/dev/null 2>&1 \
        && command -v tar >/dev/null 2>&1 \
        && command -v gzip >/dev/null 2>&1 \
        && command -v dbus-daemon >/dev/null 2>&1 \
        && command -v ip >/dev/null 2>&1 \
        && command -v iptables >/dev/null 2>&1 \
        && command -v fusermount3 >/dev/null 2>&1 \
        && command -v newuidmap >/dev/null 2>&1 \
        && command -v newgidmap >/dev/null 2>&1 \
        && { [ -s /etc/ssl/certs/ca-certificates.crt ] \
            || [ -s /etc/pki/tls/certs/ca-bundle.crt ] \
            || [ -s /etc/ssl/ca-bundle.pem ]; } \
        && { [ -r /usr/share/bash-completion/bash_completion ] \
            || [ -r /etc/bash_completion ]; }; then
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y bash-completion ca-certificates curl dbus-user-session fuse3 gzip iproute2 iptables tar uidmap
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache bash-completion ca-certificates curl dbus fuse3 gzip iproute2 iptables shadow-subids tar
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y bash-completion ca-certificates curl dbus-daemon fuse3 gzip iproute iptables shadow-utils tar
    elif command -v microdnf >/dev/null 2>&1; then
        microdnf install -y bash-completion ca-certificates curl dbus-daemon fuse3 gzip iproute iptables shadow-utils tar
    elif command -v yum >/dev/null 2>&1; then
        yum install -y bash-completion ca-certificates curl dbus fuse3 gzip iproute iptables shadow-utils tar
    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install bash-completion ca-certificates curl dbus-1 fuse3 gzip iproute2 iptables shadow tar
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm --needed bash-completion ca-certificates curl dbus fuse3 gzip iproute2 iptables shadow tar
    elif command -v xbps-install >/dev/null 2>&1; then
        xbps-install -Sy bash-completion ca-certificates curl dbus fuse3 gzip iproute2 iptables shadow tar
    elif command -v emerge >/dev/null 2>&1; then
        emerge --noreplace app-arch/gzip app-arch/tar app-misc/ca-certificates app-shells/bash-completion net-firewall/iptables net-misc/curl sys-apps/dbus sys-apps/iproute2 sys-apps/shadow sys-fs/fuse
    elif command -v eopkg >/dev/null 2>&1; then
        eopkg install -y bash-completion ca-certs curl dbus fuse3 gzip iproute2 iptables shadow tar
    else
        printf '%s\n' 'unable to install required dependencies' >&2
        exit 1
    fi
}

install_dependencies

case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *)
        printf 'unsupported architecture %s\n' "$(uname -m)" >&2
        exit 1
        ;;
esac

release_url=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/containerd/nerdctl/releases/latest)
tag=${release_url##*/}
version=${tag#v}
archive=nerdctl-full-${version}-linux-${arch}.tar.gz
download_url=https://github.com/containerd/nerdctl/releases/download/${tag}/${archive}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT HUP INT TERM

curl -fL --retry 3 -o "$workdir/$archive" "$download_url"
mkdir -p /usr/local
tar -xzf "$workdir/$archive" -C /usr/local

mkdir -p \
    /etc/bash_completion.d \
    /usr/local/share/fish/vendor_completions.d \
    /usr/local/share/zsh/site-functions

/usr/local/bin/nerdctl completion bash > /etc/bash_completion.d/nerdctl
/usr/local/bin/nerdctl completion fish > /usr/local/share/fish/vendor_completions.d/nerdctl.fish
/usr/local/bin/nerdctl completion zsh > /usr/local/share/zsh/site-functions/_nerdctl
chmod 0644 \
    /etc/bash_completion.d/nerdctl \
    /usr/local/share/fish/vendor_completions.d/nerdctl.fish \
    /usr/local/share/zsh/site-functions/_nerdctl

# configure and start the packaged daemons
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    systemctl daemon-reload
    systemctl enable --now containerd buildkit
elif command -v rc-service >/dev/null 2>&1; then
    cat > /etc/init.d/containerd <<'EOF'
#!/sbin/openrc-run

supervisor=supervise-daemon
name=containerd
description="container runtime"
command=/usr/local/bin/containerd
rc_ulimit="-c unlimited -n 1048576 -u unlimited"
retry=TERM/60/KILL/10
respawn_delay=5
respawn_max=0

depend() {
    need sysfs cgroups
    after firewall
}
EOF

    cat > /etc/init.d/buildkitd <<'EOF'
#!/sbin/openrc-run

supervisor=supervise-daemon
name=buildkitd
description="buildkit builder daemon"
command=/usr/local/bin/buildkitd
directory=/var/lib/buildkit
respawn_delay=5
respawn_max=0

depend() {
    need net localmount containerd
    after firewall
}

start_pre() {
    checkpath -d "$directory"
}
EOF

    chmod 0755 /etc/init.d/containerd /etc/init.d/buildkitd
    rc-update add containerd default
    rc-update add buildkitd default
    rc-service containerd start
    rc-service buildkitd start
fi