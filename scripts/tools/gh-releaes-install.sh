#!/usr/bin/env bash

set -euo pipefail

if (( $# != 1 )) || [[ ! $1 =~ ^[[:alnum:]_.-]+/[[:alnum:]_.-]+$ ]]; then
    printf 'Usage: %s OWNER/REPO\n' "$0" >&2
    exit 1
fi

REPO=$1
URL="https://api.github.com/repos/$REPO/releases/latest"

WORKING_DIR=$(mktemp -d)
trap 'rm -rf -- "$WORKING_DIR"' EXIT

RELEASE_JSON="$WORKING_DIR/release-data.json"
ASSET_PATH="$WORKING_DIR/download"
EXTRACT_DIR="$WORKING_DIR/extracted"
mkdir -p "$EXTRACT_DIR"

# get release metadata
curl -fsSL -H 'Accept: application/vnd.github+json' \
    -o "$RELEASE_JSON" "$URL"

# display available assets
mapfile -t asset_names < <(jq -r '.assets[].name' "$RELEASE_JSON")

if (( ${#asset_names[@]} == 0 )); then
    echo 'Error: No release assets found.' >&2
    exit 1
fi

printf 'Latest release: %s\n\n' "$(jq -r '.tag_name' "$RELEASE_JSON")"

for i in "${!asset_names[@]}"; do
    printf '[%s] %s\n' "$i" "${asset_names[$i]}"
done

printf '\n'
read -r -p 'Select asset index: ' ASSET_INDEX

if [[ ! $ASSET_INDEX =~ ^(0|[1-9][0-9]*)$ ]]; then
    echo 'Error: Invalid asset index.' >&2
    exit 1
fi

# get selected asset metadata
if ! ASSET_DATA=$(jq -ce --argjson index "$ASSET_INDEX" \
    '.assets[$index] // empty' "$RELEASE_JSON"); then
    echo 'Error: Asset index is out of range.' >&2
    exit 1
fi

ASSET_NAME=$(jq -r '.name' <<< "$ASSET_DATA")
DOWNLOAD_URL=$(jq -r '.browser_download_url' <<< "$ASSET_DATA")
DIGEST=$(jq -r '.digest // empty' <<< "$ASSET_DATA")

if [[ ! $DIGEST =~ ^sha256:[[:xdigit:]]{64}$ ]]; then
    echo 'Error: Asset does not have a valid SHA-256 digest.' >&2
    exit 1
fi

# download asset
printf '\nDownloading %s\n' "$ASSET_NAME"

curl -fL --retry 3 \
    -o "$ASSET_PATH" "$DOWNLOAD_URL"

# verify checksum
if ! printf '%s  %s\n' "${DIGEST#sha256:}" "$ASSET_PATH" |
    sha256sum -c --status; then
    echo 'Error: SHA-256 verification failed.' >&2
    exit 1
fi

printf 'SHA-256 verification passed.\n\n'

# extract downloaded asset
case "$ASSET_NAME" in
    *.tar|*.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar.bz2|*.tbz2|*.tar.zst)
        tar -xf "$ASSET_PATH" -C "$EXTRACT_DIR" \
            --no-same-owner --no-same-permissions
        ;;
    *.zip)
        unzip -q "$ASSET_PATH" -d "$EXTRACT_DIR"
        ;;
    *.gz)
        gzip -dc "$ASSET_PATH" > "$EXTRACT_DIR/${ASSET_NAME%.gz}"
        ;;
    *.xz)
        xz -dc "$ASSET_PATH" > "$EXTRACT_DIR/${ASSET_NAME%.xz}"
        ;;
    *)
        cp -- "$ASSET_PATH" "$EXTRACT_DIR/$ASSET_NAME"
        ;;
esac

# display extracted files
printf 'Extracted files:\n'
ls -lA "$EXTRACT_DIR"

printf '\n'
read -r -p 'File to install (relative to extracted directory): ' SELECTED_FILE

# validate selected file
if ! SOURCE=$(realpath -e -- "$EXTRACT_DIR/$SELECTED_FILE"); then
    echo 'Error: Selected file does not exist.' >&2
    exit 1
fi

if [[ $SOURCE != "$EXTRACT_DIR/"* || ! -f $SOURCE ]]; then
    echo 'Error: Selection must be a regular file inside the extracted directory.' >&2
    exit 1
fi

# install selected file
DEFAULT_NAME=$(basename -- "$SELECTED_FILE")

read -r -p "Install filename [$DEFAULT_NAME]: " INSTALL_NAME
INSTALL_NAME=${INSTALL_NAME:-$DEFAULT_NAME}

if [[ $INSTALL_NAME == "." || $INSTALL_NAME == ".." || $INSTALL_NAME == */* ]]; then
    echo "Error: Invalid installation filename." >&2
    exit 1
fi

DEST="/usr/local/bin/$INSTALL_NAME"

if (( EUID == 0 )); then
    install -m 0755 -o root -g root -- "$SOURCE" "$DEST"
else
    sudo install -m 0755 -o root -g root -- "$SOURCE" "$DEST"
fi

printf '\nInstalled: %s\n' "$DEST"
