#!/bin/sh

# run this on truenas or another host with write access to the repo

set -eu

BORG_BIN=${BORG_BIN:-/mnt/fastpool/bin/borg-server/borg}
TMPDIR=${TMPDIR:-/var/tmp}
MODE=${MODE:-single}

REPO_PATH=${REPO_PATH:-/mnt/coldpool/borg/lab/sample-host}
REPO_ROOT=${REPO_ROOT:-/mnt/coldpool/borg/lab}

KEEP_DAILY=${KEEP_DAILY:-7}
KEEP_WEEKLY=${KEEP_WEEKLY:-4}
KEEP_MONTHLY=${KEEP_MONTHLY:-12}
KEEP_YEARLY=${KEEP_YEARLY:-2}

if [ -n "${BORG_PASSPHRASE_FILE:-}" ]; then
    if [ -z "${BORG_PASSCOMMAND:-}" ]; then
        BORG_PASSCOMMAND="cat $BORG_PASSPHRASE_FILE"
    fi
    export BORG_PASSCOMMAND
fi

export TMPDIR

run_repo() {
    repo=$1

    echo maintaining "$repo"

    "$BORG_BIN" prune \
        --list \
        --keep-daily "$KEEP_DAILY" \
        --keep-weekly "$KEEP_WEEKLY" \
        --keep-monthly "$KEEP_MONTHLY" \
        --keep-yearly "$KEEP_YEARLY" \
        "$repo"

    "$BORG_BIN" compact "$repo"

    "$BORG_BIN" check --repository-only "$repo"
}

case "$MODE" in
    single)
        run_repo "$REPO_PATH"
        ;;
    walk)
        find "$REPO_ROOT" -name config -type f -print | while IFS= read -r config_file; do
            run_repo "$(dirname "$config_file")"
        done
        ;;
    *)
        echo unknown mode
        exit 1
        ;;
esac

echo done
