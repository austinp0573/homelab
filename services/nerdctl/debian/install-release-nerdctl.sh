#!/bin/sh
set -eu

#
# nerdctl-full installer/updater
#
# Override from the environment if desired:
#
#   VERSION=2.3.5 ./install-release-nerdctl.sh
#   VERSION=2.3.5 ARCH=arm64 ./install-release-nerdctl.sh
#
# ARCH is automatically detected for amd64 and arm64 if unset.
#

VERSION="${VERSION:-2.3.5}"

if [ -z "${ARCH:-}" ]; then
    case "$(uname -m)" in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            printf 'Error: unsupported architecture: %s\n' "$(uname -m)" >&2
            exit 1
            ;;
    esac
fi

case "$ARCH" in
    amd64|arm64)
        ;;
    *)
        printf 'Error: unsupported ARCH: %s\n' "$ARCH" >&2
        exit 1
        ;;
esac

RELEASE="nerdctl-full-${VERSION}-linux-${ARCH}.tar.gz"
URL="https://github.com/containerd/nerdctl/releases/download/v${VERSION}/${RELEASE}"

STATE_DIR="/var/lib/nerdctl-full"
MANIFEST="${STATE_DIR}/manifest"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

ARCHIVE="${TMP_DIR}/${RELEASE}"
NEW_MANIFEST_RAW="${TMP_DIR}/manifest.new.raw"
NEW_MANIFEST="${TMP_DIR}/manifest.new"
OLD_MANIFEST="${TMP_DIR}/manifest.old"
STALE_MANIFEST="${TMP_DIR}/manifest.stale"
STALE_MANIFEST_REVERSED="${TMP_DIR}/manifest.stale.reversed"

# Start with an empty old manifest. This represents a fresh installation.
: > "$OLD_MANIFEST"

printf '\nInstalling nerdctl-full %s for %s\n' "$VERSION" "$ARCH"

printf '\nDownloading %s...\n' "$RELEASE"
curl -fL --retry 3 --output "$ARCHIVE" "$URL"

printf 'Validating archive...\n'
tar -tzf "$ARCHIVE" > "$NEW_MANIFEST_RAW"
LC_ALL=C sort -u "$NEW_MANIFEST_RAW" > "$NEW_MANIFEST"

#
# Load the manifest from the previous installation.
#
# New versions of this script store the manifest in /var/lib/nerdctl-full.
#
# If this is the first run of the new installer but nerdctl is already
# installed in /usr/local, determine the old version and download that
# release once so we can reconstruct its manifest.
#

if sudo test -f "$MANIFEST"; then
    sudo cat "$MANIFEST" > "$OLD_MANIFEST"

elif [ -x /usr/local/bin/nerdctl ]; then
    OLD_VERSION="$(
        /usr/local/bin/nerdctl --version 2>/dev/null |
            awk '$1 == "nerdctl" && $2 == "version" { print $3; exit }'
    )"

    if [ -z "$OLD_VERSION" ]; then
        printf 'Error: nerdctl is installed, but its version could not be determined.\n' >&2
        exit 1
    fi

    printf '\nExisting nerdctl installation detected: %s\n' "$OLD_VERSION"

    if [ "$OLD_VERSION" = "$VERSION" ]; then
        #
        # Same release. The new archive itself represents the old
        # installation, so no second download is necessary.
        #
        cp "$NEW_MANIFEST" "$OLD_MANIFEST"
    else
        OLD_RELEASE="nerdctl-full-${OLD_VERSION}-linux-${ARCH}.tar.gz"
        OLD_URL="https://github.com/containerd/nerdctl/releases/download/v${OLD_VERSION}/${OLD_RELEASE}"
        OLD_ARCHIVE="${TMP_DIR}/${OLD_RELEASE}"
        OLD_MANIFEST_RAW="${TMP_DIR}/manifest.old.raw"

        printf 'Reconstructing manifest for previous release %s...\n' "$OLD_VERSION"

        curl -fL --retry 3 --output "$OLD_ARCHIVE" "$OLD_URL"

        tar -tzf "$OLD_ARCHIVE" > "$OLD_MANIFEST_RAW"
        LC_ALL=C sort -u "$OLD_MANIFEST_RAW" > "$OLD_MANIFEST"
    fi
fi

#
# Install the new release.
#
# Extract first, then remove files that existed only in the old release.
# This avoids unnecessarily removing binaries that are present in both
# releases before their replacements have been installed.
#

printf '\nExtracting %s to /usr/local...\n' "$RELEASE"
sudo tar -C /usr/local -xzf "$ARCHIVE"

#
# Remove files that belonged to the old nerdctl-full release but are not
# present in the new one.
#

LC_ALL=C comm -23 "$OLD_MANIFEST" "$NEW_MANIFEST" > "$STALE_MANIFEST"

if [ -s "$STALE_MANIFEST" ]; then
    printf '\nRemoving obsolete files from the previous release...\n'

    while IFS= read -r path; do
        case "$path" in
            ""|*/)
                ;;
            *)
                sudo rm -f -- "/usr/local/$path"
                ;;
        esac
    done < "$STALE_MANIFEST"

    #
    # Remove obsolete directories if they are now empty.
    # Reverse sorting generally processes children before parents.
    #

    LC_ALL=C sort -r "$STALE_MANIFEST" > "$STALE_MANIFEST_REVERSED"

    while IFS= read -r path; do
        case "$path" in
            */)
                sudo rmdir -- "/usr/local/${path%/}" 2>/dev/null || true
                ;;
        esac
    done < "$STALE_MANIFEST_REVERSED"
fi

#
# Remove the old systemd symlinks created by previous versions of this
# installer. /usr/local/lib/systemd/system is already part of systemd's
# normal system-unit search path.
#

for unit in containerd.service buildkit.service; do
    legacy_unit="/lib/systemd/system/$unit"

    if [ -L "$legacy_unit" ] &&
       [ "$(readlink "$legacy_unit")" = "/usr/local/lib/systemd/system/$unit" ]; then
        printf 'Removing obsolete systemd symlink: %s\n' "$legacy_unit"
        sudo rm -f "$legacy_unit"
    fi
done

#
# Record exactly what this release installed.
#

sudo install -d -m 0755 "$STATE_DIR"
sudo install -m 0644 "$NEW_MANIFEST" "$MANIFEST"

#
# Reload systemd, make sure the services are enabled, and restart them so
# the newly installed binaries are actually running.
#

printf '\nReloading systemd...\n'
sudo systemctl daemon-reload

printf 'Enabling systemd services...\n'
sudo systemctl reenable containerd.service buildkit.service

printf 'Restarting containerd...\n'
sudo systemctl restart containerd.service

printf 'Restarting BuildKit...\n'
sudo systemctl restart buildkit.service

printf '\nInstalled versions:\n'
/usr/local/bin/nerdctl --version
/usr/local/bin/containerd --version
/usr/local/bin/buildkitd --version

printf '\nService status:\n'
sudo systemctl is-active containerd.service
sudo systemctl is-active buildkit.service

printf '\nnerdctl-full %s installation/update completed successfully.\n' "$VERSION"