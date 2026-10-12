#!/bin/sh

set -eu

# configuration

ALPINE_VERSION="${ALPINE_VERSION:-}"
APK_MIRROR="${APK_MIRROR:-https://dl-cdn.alpinelinux.org/alpine}"
UPGRADE_PACKAGES="${UPGRADE_PACKAGES:-yes}"

ACCOUNT_NAME="${ACCOUNT_NAME:}"
ACCOUNT_UID="${ACCOUNT_UID:}"
ACCOUNT_PASSWORD="${ACCOUNT_PASSWORD:-}"
LOGIN_SHELL="${LOGIN_SHELL:-}"
GITHUB_USER="${GITHUB_USER:-}"
SSH_PORT="${SSH_PORT:-22}"
TIMEZONE="${TIMEZONE:-America/Chicago}"
SERIAL_DEVICE="${SERIAL_DEVICE:-ttyS0}"
SERIAL_BAUD="${SERIAL_BAUD:-115200}"

ZRAM_ENABLED="${ZRAM_ENABLED:-yes}"
ZRAM_SIZE_MIB="${ZRAM_SIZE_MIB:-0}"
ZRAM_PERCENT="${ZRAM_PERCENT:-50}"
ZRAM_MIN_MIB="${ZRAM_MIN_MIB:-32}"
ZRAM_MAX_MIB="${ZRAM_MAX_MIB:-8192}"
ZRAM_ALGORITHM="${ZRAM_ALGORITHM:-lz4}"
ZRAM_PRIORITY="${ZRAM_PRIORITY:-100}"

DISK_SWAP_ENABLED="${DISK_SWAP_ENABLED:-yes}"
SWAP_FILE="${SWAP_FILE:-/swapfile}"
SWAP_SIZE_MIB="${SWAP_SIZE_MIB:-0}"
SWAP_PERCENT="${SWAP_PERCENT:-100}"
SWAP_MIN_MIB="${SWAP_MIN_MIB:-512}"
SWAP_MAX_MIB="${SWAP_MAX_MIB:-8192}"
SWAP_PRIORITY="${SWAP_PRIORITY:-10}"
SWAP_DISK_RESERVE_MIB="${SWAP_DISK_RESERVE_MIB:-256}"
SWAPPINESS="${SWAPPINESS:-60}"
SWAP_PAGE_CLUSTER="${SWAP_PAGE_CLUSTER:-3}"

BLACKLIST_MODULES="${BLACKLIST_MODULES:-
snd_hda_intel
snd_intel_dspcfg
snd_hda_codec
snd_hwdep
snd_hda_core
snd_pcm
snd_timer
snd
psmouse
kvm_intel
kvm_amd
kvm
usbcore
usb_common
ehci_hcd
ehci_pci
uhci_hcd
usbhid
}"

# preflight checks

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

if [ -z "$ACCOUNT_PASSWORD" ] || [ -z "$GITHUB_USER" ]; then
	echo "Set ACCOUNT_PASSWORD and GITHUB_USER before running this script" >&2
	exit 1
fi

if id "$ACCOUNT_NAME" >/dev/null 2>&1; then
	echo "Use this script on a fresh install before creating $ACCOUNT_NAME" >&2
	exit 1
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
trap 'exit 1' HUP INT TERM

case "$ACCOUNT_NAME" in
	root|''|*[!a-z0-9_-]*)
		echo "Set ACCOUNT_NAME to a valid nonroot username" >&2
		exit 1
		;;
esac

if awk -F : -v uid="$ACCOUNT_UID" '$3 == uid { found = 1 } END { exit !found }' /etc/passwd; then
	echo "ACCOUNT_UID is already assigned to another account" >&2
	exit 1
fi

case "$ACCOUNT_PASSWORD" in
	*'
'*)
		echo "ACCOUNT_PASSWORD must not contain a newline" >&2
		exit 1
		;;
esac

case "$GITHUB_USER" in
	*[!a-zA-Z0-9-]*)
		echo "Set GITHUB_USER to a GitHub username" >&2
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

case "$SERIAL_DEVICE" in
	ttyS[0-9]) SERIAL_PORT=${SERIAL_DEVICE#ttyS} ;;
	*)
		echo "Choose a PC serial port such as ttyS0" >&2
		exit 1
		;;
esac

if [ -f /etc/update-extlinux.conf ] && command -v update-extlinux >/dev/null 2>&1; then
	BOOTLOADER=extlinux
elif [ -f /etc/default/grub ] && command -v grub-mkconfig >/dev/null 2>&1; then
	BOOTLOADER=grub
else
	echo "This script requires extlinux or grub for serial console setup" >&2
	exit 1
fi

for value in "$ZRAM_ENABLED" "$DISK_SWAP_ENABLED" "$UPGRADE_PACKAGES"; do
	case "$value" in
		yes|no) ;;
		*)
			echo "Enable settings must be yes or no" >&2
			exit 1
			;;
	esac
done

for value in "$ACCOUNT_UID" "$SSH_PORT" "$SERIAL_BAUD" \
	"$ZRAM_SIZE_MIB" "$ZRAM_PERCENT" "$ZRAM_MIN_MIB" "$ZRAM_MAX_MIB" \
	"$ZRAM_PRIORITY" "$SWAP_SIZE_MIB" "$SWAP_PERCENT" "$SWAP_MIN_MIB" \
	"$SWAP_MAX_MIB" "$SWAP_PRIORITY" "$SWAP_DISK_RESERVE_MIB" \
	"$SWAPPINESS" "$SWAP_PAGE_CLUSTER"; do
	case "$value" in
		''|*[!0-9]*|0[0-9]*)
			echo "Numeric settings must be whole numbers without leading zeroes" >&2
			exit 1
			;;
	esac
done

if [ "$ACCOUNT_UID" -eq 0 ] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
	echo "Use a nonroot UID and an SSH port from 1 to 65535" >&2
	exit 1
fi

if [ "$ZRAM_PRIORITY" -le "$SWAP_PRIORITY" ] || [ "$ZRAM_PRIORITY" -gt 32767 ]; then
	echo "ZRAM_PRIORITY must exceed SWAP_PRIORITY and must not exceed 32767" >&2
	exit 1
fi

if [ "$ZRAM_MIN_MIB" -lt 1 ] || [ "$ZRAM_MIN_MIB" -gt "$ZRAM_MAX_MIB" ] ||
	[ "$SWAP_MIN_MIB" -lt 1 ] || [ "$SWAP_MIN_MIB" -gt "$SWAP_MAX_MIB" ]; then
	echo "Swap minimums must be positive and must not exceed maximums" >&2
	exit 1
fi

if [ "$SWAPPINESS" -gt 200 ] || [ "$SWAP_PAGE_CLUSTER" -gt 31 ]; then
	echo "Invalid swap tuning values" >&2
	exit 1
fi

case "$SWAP_FILE" in
	/*) ;;
	*)
		echo "SWAP_FILE must be an absolute path" >&2
		exit 1
		;;
esac

case "$SWAP_FILE" in
	*[[:space:]]*)
		echo "SWAP_FILE must not contain whitespace" >&2
		exit 1
		;;
esac

if [ -L "$SWAP_FILE" ]; then
	echo "SWAP_FILE must not be a symlink" >&2
	exit 1
fi

if [ -e "$SWAP_FILE" ]; then
	if [ ! -f "$SWAP_FILE" ]; then
		echo "SWAP_FILE must be a regular file" >&2
		exit 1
	fi
	if ! awk -v path="$SWAP_FILE" '$1 == path && $3 == "swap" { found = 1 } END { exit !found }' /etc/fstab; then
		echo "Refusing to overwrite a file not registered as swap" >&2
		exit 1
	fi
fi

# configure matching stable repositories

cp -p /etc/apk/repositories /etc/apk/repositories.before-base

cat << EOF | tee /etc/apk/repositories
$APK_MIRROR/v$ALPINE_VERSION/main
$APK_MIRROR/v$ALPINE_VERSION/community
EOF

apk update

# replace installer time clients with busybox ntpd

for service in chronyd ntpd; do
	if [ -x "/etc/init.d/$service" ]; then
		if rc-service "$service" status >/dev/null 2>&1; then
			rc-service "$service" stop
		fi
		rc-update del "$service" || true
	fi
done

for package in chrony openntpd; do
	if apk info -e "$package" >/dev/null 2>&1; then
		apk del "$package"
	fi
done

apk add dropbear doas ca-certificates tzdata qemu-guest-agent busybox-openrc
apk add --virtual .base-fetch curl openssh-keygen

if [ "$LOGIN_SHELL" = /bin/bash ]; then
	apk add bash
fi

# validate github keys before changing ssh access

curl --fail --silent --show-error --location --retry 3 \
	--connect-timeout 15 --max-time 60 \
	"https://github.com/$GITHUB_USER.keys" -o "$WORK_DIR/authorized_keys"
ssh-keygen -l -f "$WORK_DIR/authorized_keys"

# zero sizes use the configured percentages and limits

TOTAL_RAM_MIB=$(awk '/^MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)

if [ "$ZRAM_SIZE_MIB" -eq 0 ]; then
	ZRAM_SIZE_MIB=$((TOTAL_RAM_MIB * ZRAM_PERCENT / 100))
	if [ "$ZRAM_SIZE_MIB" -lt "$ZRAM_MIN_MIB" ]; then
		ZRAM_SIZE_MIB=$ZRAM_MIN_MIB
	fi
	if [ "$ZRAM_SIZE_MIB" -gt "$ZRAM_MAX_MIB" ]; then
		ZRAM_SIZE_MIB=$ZRAM_MAX_MIB
	fi
fi

if [ "$SWAP_SIZE_MIB" -eq 0 ]; then
	SWAP_SIZE_MIB=$((TOTAL_RAM_MIB * SWAP_PERCENT / 100))
	if [ "$SWAP_SIZE_MIB" -lt "$SWAP_MIN_MIB" ]; then
		SWAP_SIZE_MIB=$SWAP_MIN_MIB
	fi
	if [ "$SWAP_SIZE_MIB" -gt "$SWAP_MAX_MIB" ]; then
		SWAP_SIZE_MIB=$SWAP_MAX_MIB
	fi
fi

# use compressed swap before disk swap

if [ "$ZRAM_ENABLED" = yes ]; then
	apk add zram-init

	cat << EOF | tee /etc/conf.d/zram-init
load_on_start=yes
unload_on_stop=yes
num_devices=1
type0=swap
size0=$ZRAM_SIZE_MIB
algo0=$ZRAM_ALGORITHM
flag0=$ZRAM_PRIORITY
EOF

	rc-update add zram-init boot
	rc-service zram-init start
fi

# create replacement disk swap

cp -p /etc/fstab /etc/fstab.before-base

if [ "$DISK_SWAP_ENABLED" = yes ]; then
	mkdir -p "$(dirname "$SWAP_FILE")"
	FREE_DISK_MIB=$(df -Pm "$(dirname "$SWAP_FILE")" | awk 'NR == 2 { print $4 }')

	if [ -f "$SWAP_FILE" ]; then
		OLD_SWAP_MIB=$(du -m "$SWAP_FILE" | awk '{ print $1 }')
		FREE_DISK_MIB=$((FREE_DISK_MIB + OLD_SWAP_MIB))
	fi

	REQUIRED_DISK_MIB=$((SWAP_SIZE_MIB + SWAP_DISK_RESERVE_MIB))
	if [ "$FREE_DISK_MIB" -lt "$REQUIRED_DISK_MIB" ]; then
		echo "Not enough disk space for swap while keeping the configured reserve" >&2
		exit 1
	fi

	if awk -v path="$SWAP_FILE" '$1 == path { found = 1 } END { exit !found }' /proc/swaps; then
		swapoff "$SWAP_FILE"
	fi
	touch "$SWAP_FILE"
	chmod 600 "$SWAP_FILE"
	dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$SWAP_SIZE_MIB"
	mkswap "$SWAP_FILE"
	swapon -p "$SWAP_PRIORITY" "$SWAP_FILE"
fi

# retire other disk swap only after its replacement is active

awk 'NR > 1 && $1 !~ /^\/dev\/zram/ { print $1 }' /proc/swaps > "$WORK_DIR/disk-swap"

while IFS= read -r old_swap; do
	if [ "$DISK_SWAP_ENABLED" = yes ] && [ "$old_swap" = "$SWAP_FILE" ]; then
		continue
	fi
	swapoff "$old_swap"
done < "$WORK_DIR/disk-swap"

awk '$3 != "swap" { print }' /etc/fstab > "$WORK_DIR/fstab"

if [ "$DISK_SWAP_ENABLED" = yes ]; then
	printf '%s none swap sw,pri=%s 0 0\n' "$SWAP_FILE" "$SWAP_PRIORITY" >> "$WORK_DIR/fstab"
fi

cat "$WORK_DIR/fstab" > /etc/fstab
rc-update add swap boot

# keep kernel defaults unless the configuration above overrides them

cat << EOF | tee /etc/sysctl.d/60-swap.conf
vm.swappiness=$SWAPPINESS
vm.page-cluster=$SWAP_PAGE_CLUSTER
EOF

sysctl -p /etc/sysctl.d/60-swap.conf

if [ "$UPGRADE_PACKAGES" = yes ]; then
	apk upgrade
fi

# keep the selected zone file without the full timezone database

if [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
	echo "Unknown timezone $TIMEZONE" >&2
	exit 1
fi

cp -L "/usr/share/zoneinfo/$TIMEZONE" "$WORK_DIR/localtime"
mv -f "$WORK_DIR/localtime" /etc/localtime
printf '%s\n' "$TIMEZONE" > /etc/timezone
apk del tzdata

# create the configured user and use the selected shell for root as well

adduser -D -h "/home/$ACCOUNT_NAME" -u "$ACCOUNT_UID" \
	-s "$LOGIN_SHELL" "$ACCOUNT_NAME"
addgroup "$ACCOUNT_NAME" wheel

printf '%s:%s\n' "$ACCOUNT_NAME" "$ACCOUNT_PASSWORD" | chpasswd
unset ACCOUNT_PASSWORD

awk -F : -v OFS=: -v shell="$LOGIN_SHELL" '
    $1 == "root" { $7 = shell }
    { print }
' /etc/passwd > "$WORK_DIR/passwd"

cat "$WORK_DIR/passwd" > /etc/passwd

mkdir -p /etc/doas.d

cat << EOF | tee /etc/doas.d/10-user.conf
permit persist $ACCOUNT_NAME
EOF

chmod 600 /etc/doas.d/10-user.conf
doas -C /etc/doas.d/10-user.conf

# install the same github keys for root and the configured user

mkdir -p /root/.ssh "/home/$ACCOUNT_NAME/.ssh"
cp "$WORK_DIR/authorized_keys" /root/.ssh/authorized_keys
cp "$WORK_DIR/authorized_keys" "/home/$ACCOUNT_NAME/.ssh/authorized_keys"
chmod 700 /root/.ssh "/home/$ACCOUNT_NAME/.ssh"
chmod 600 /root/.ssh/authorized_keys "/home/$ACCOUNT_NAME/.ssh/authorized_keys"
chown -R "$ACCOUNT_NAME:$ACCOUNT_NAME" "/home/$ACCOUNT_NAME/.ssh"

# disable password authentication for every ssh account including root

cat << EOF | tee /etc/conf.d/dropbear
DROPBEAR_OPTS="-s -p $SSH_PORT"
EOF

if [ -x /etc/init.d/sshd ]; then
	if rc-service sshd status >/dev/null 2>&1; then
		rc-service sshd stop
	fi
	rc-update del sshd || true
fi

rc-update add dropbear default
rc-service dropbear restart

# keep cron logging time sync and guest integration
# retain acpi handling for host initiated shutdown

rc-update add crond default
rc-update add syslog boot
rc-update add ntpd default
rc-update add qemu-guest-agent default
rc-service crond start
rc-service syslog start
rc-service ntpd start

modprobe virtio_console

if [ -e /dev/virtio-ports/org.qemu.guest_agent.0 ]; then
	rc-service qemu-guest-agent start
else
	echo "Enable the QEMU Guest Agent channel in Proxmox before the next boot"
fi

# only the serial console needs a login process

cp -p /etc/inittab /etc/inittab.before-base
sed -i '/^tty[1-6]::/s/^/#/' /etc/inittab
sed -i "/^$SERIAL_DEVICE::/d" /etc/inittab

cat << EOF | tee -a /etc/inittab
$SERIAL_DEVICE::respawn:/sbin/getty -L $SERIAL_BAUD $SERIAL_DEVICE vt100
EOF

touch /etc/securetty

if ! grep -qx "$SERIAL_DEVICE" /etc/securetty; then
	printf '%s\n' "$SERIAL_DEVICE" >> /etc/securetty
fi

if [ "$BOOTLOADER" = extlinux ]; then
	cp -p /etc/update-extlinux.conf /etc/update-extlinux.conf.before-base
	sed -i '/^serial_port=/d; /^serial_baud=/d' /etc/update-extlinux.conf

	cat << EOF | tee -a /etc/update-extlinux.conf
serial_port=$SERIAL_PORT
serial_baud=$SERIAL_BAUD
default_kernel_opts="\$default_kernel_opts console=$SERIAL_DEVICE,${SERIAL_BAUD}n8"
EOF

	update-extlinux
else
	cp -p /etc/default/grub /etc/default/grub.before-base

	cat << EOF | tee -a /etc/default/grub
GRUB_TERMINAL=serial
GRUB_SERIAL_COMMAND="serial --speed=$SERIAL_BAUD --unit=$SERIAL_PORT --word=8 --parity=no --stop=1"
GRUB_CMDLINE_LINUX="\$GRUB_CMDLINE_LINUX console=$SERIAL_DEVICE,${SERIAL_BAUD}n8"
EOF

	grub-mkconfig -o /boot/grub/grub.cfg
fi

if [ -x /etc/init.d/loadkmap ]; then
	rc-update del loadkmap || true
fi

# blacklist unused virtual hardware without unloading live drivers
# keep power handling virtio filesystems crypto and all container support

: > /etc/modprobe.d/minimal-vm.conf

for module in $BLACKLIST_MODULES; do
	printf 'blacklist %s\n' "$module" >> /etc/modprobe.d/minimal-vm.conf
done

# include the blacklist in early boot without reducing initramfs features

for module_dir in /lib/modules/*; do
	if [ -d "$module_dir" ]; then
		mkinitfs "${module_dir##*/}"
	fi
done

# remove temporary tools and unused openssh server packages

apk del .base-fetch

for package in openssh openssh-server openssh-sftp-server kbd-bkeymaps kbd-misc; do
	if apk info -e "$package" >/dev/null 2>&1; then
		apk del "$package"
	fi
done

apk cache clean

echo "Base setup complete"
echo "Test a new SSH connection with your GitHub key before closing this session"
echo "Configure Proxmox serial0 as socket and display as serial0 if not already set"
echo "Reboot manually to apply console and module changes"
free -m
cat /proc/swaps
