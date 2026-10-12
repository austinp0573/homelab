#!/bin/sh

set -eu

# configuration

ALPINE_VERSION="${ALPINE_VERSION:-}"
APK_MIRROR="${APK_MIRROR:-https://dl-cdn.alpinelinux.org/alpine}"
UPGRADE_PACKAGES="${UPGRADE_PACKAGES:-yes}"
ACCOUNT_NAME="${ACCOUNT_NAME:-austin}"
LOGIN_SHELL="${LOGIN_SHELL:-/bin/bash}"
EDITOR="${EDITOR:-vim}"

# run as root on a fresh alpine installation or after base
# use the same account name in both scripts
# account creation keys timezone and swap belong to base

if [ "$(id -u)" != 0 ]; then
	echo "Run this script as root" >&2
	exit 1
fi

if [ ! -f /etc/alpine-release ]; then
	echo "This script requires Alpine Linux" >&2
	exit 1
fi

INSTALLED_VERSION=$(cut -d . -f 1,2 /etc/alpine-release)

if [ "$ALPINE_VERSION" != "$INSTALLED_VERSION" ]; then
	echo "Set ALPINE_VERSION to the installed release $INSTALLED_VERSION" >&2
	exit 1
fi

case "$UPGRADE_PACKAGES" in
	yes|no) ;;
	*)
		echo "UPGRADE_PACKAGES must be yes or no" >&2
		exit 1
		;;
esac

case "$LOGIN_SHELL" in
	/bin/ash|/bin/sh|/bin/bash) ;;
	*)
		echo "LOGIN_SHELL must be /bin/ash /bin/sh or /bin/bash" >&2
		exit 1
		;;
esac

# only nerdctl comes from edge
# do not broaden edge usage if it conflicts with the installed stable release

cp -p /etc/apk/repositories /etc/apk/repositories.before-container

cat << EOF | tee /etc/apk/repositories
$APK_MIRROR/v$ALPINE_VERSION/main
$APK_MIRROR/v$ALPINE_VERSION/community
@edge $APK_MIRROR/edge/community
EOF

apk update

if [ "$UPGRADE_PACKAGES" = yes ]; then
	apk upgrade
fi

apk add containerd buildkit cni-plugins iptables ip6tables
apk add --upgrade nerdctl@edge
apk add openssh-sftp-server bat ripgrep bash bash-completion vim fastfetch doas

# use cgroupfs without systemd

mkdir -p /etc/nerdctl /etc/modules-load.d /etc/sysctl.d

cat << 'EOF' | tee /etc/nerdctl/nerdctl.toml
cgroup_manager = "cgroupfs"
EOF

sed -i '/^rc_cgroup_mode=/d' /etc/rc.conf
printf 'rc_cgroup_mode="unified"\n' >> /etc/rc.conf
rc-update add cgroups boot
rc-service cgroups start

if [ ! -f /sys/fs/cgroup/cgroup.controllers ]; then
	echo "Cgroup v2 has been configured reboot manually and run this script again" >&2
	exit 1
fi

# enable normal overlay storage and bridge networking
# keep host addressing dns and firewall policy unchanged

cat << 'EOF' | tee /etc/modules-load.d/container-host.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat << 'EOF' | tee /etc/sysctl.d/99-forward-ipv4.conf
net.ipv4.ip_forward=1
EOF

sysctl -w net.ipv4.ip_forward=1

rc-update add containerd default
rc-update add buildkitd default
rc-service containerd start
rc-service buildkitd start

# use the selected shell for root and an existing user

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
trap 'exit 1' HUP INT TERM

awk -F : -v OFS=: -v account="$ACCOUNT_NAME" -v shell="$LOGIN_SHELL" '
    $1 == "root" || $1 == account { $7 = shell }
    { print }
' /etc/passwd > "$WORK_DIR/passwd"

cat "$WORK_DIR/passwd" > /etc/passwd

if id "$ACCOUNT_NAME" >/dev/null 2>&1; then
	mkdir -p /etc/doas.d

	cat << EOF | tee /etc/doas.d/10-user.conf
permit persist $ACCOUNT_NAME
EOF

	chmod 600 /etc/doas.d/10-user.conf
	doas -C /etc/doas.d/10-user.conf
else
	echo "No account named $ACCOUNT_NAME exists only the root shell was changed"
fi

# enable the packaged prompt and vim line numbers

if [ -f /etc/profile.d/color_prompt.sh.disabled ]; then
	ln -sf /etc/profile.d/color_prompt.sh.disabled /etc/profile.d/color_prompt.sh
fi

mkdir -p /etc/vim

if ! grep -qx 'set nu' /etc/vim/vimrc; then
	printf 'set nu\n' >> /etc/vim/vimrc
fi

# only interactive bash should load bash completion

cat << 'EOF' | tee /etc/profile.d/15-bash-completion.sh
if [ -n "${BASH_VERSION:-}" ]; then
	case $- in
		*i*)
			if ! shopt -oq posix; then
				if [ -f /usr/share/bash-completion/bash_completion ]; then
					. /usr/share/bash-completion/bash_completion
				fi
			fi
			;;
	esac
fi
EOF

cat << EOF | tee /etc/profile.d/10-basic-shell.sh
export EDITOR="$EDITOR"
EOF

cat << 'EOF' | tee -a /etc/profile.d/10-basic-shell.sh

case $- in
	*i*)
		alias ls='ls --color=auto'
		alias grep='grep --color=auto'
		alias l='ls -Alrth'

		if [ -f "$HOME/.ash_aliases" ]; then
			. "$HOME/.ash_aliases"
		fi
		;;
esac
EOF

: > /etc/motd

# keep welcome output out of noninteractive ssh and file transfers

cat << 'EOF' | tee /etc/profile.d/30-welcome-message.sh
case $- in
	*i*)
		if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ]; then
			clear
			printf '\n'
			fastfetch
			printf '\n\n'
			printf 'welcome to %s %s - time %s\n' "$(hostname)" "$(id -un)" "$(date)"
			printf '\n'
		fi
		;;
esac
EOF

apk cache clean

echo "Container host setup complete"
echo "Use doas nerdctl from your normal account"
echo "No SSH server or authentication settings were changed"
nerdctl --version
containerd --version
buildkitd --version
