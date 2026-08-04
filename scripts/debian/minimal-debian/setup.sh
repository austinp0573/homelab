#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"

export MINIMAL_DEBIAN_APT_STAMP="/tmp/minimal-debian-apt-updated-$$"
trap 'rm -f "$MINIMAL_DEBIAN_APT_STAMP"' EXIT

run_script() {
    local script="$1"
    echo "running $script"
    # shellcheck disable=SC1090
    bash "$script"
}

echo "core"
ssh_script=""
for script in "$ROOT_DIR"/core/*.sh; do
    [ -f "$script" ] || continue
    case "$(basename "$script")" in
        40-ssh.sh)
            ssh_script="$script"
            ;;
        50-ssh-keys.sh)
            run_script "$script"
            [ -z "$ssh_script" ] || run_script "$ssh_script"
            ;;
        *)
            run_script "$script"
            ;;
    esac
done

OPTIONAL_DIR="$ROOT_DIR/optional"
OPTIONAL_RUN="${OPTIONAL_RUN:-}"
OPTIONAL_PROMPT="${OPTIONAL_PROMPT:-y}"

run_optional_named() {
    local name="$1"
    local path="$OPTIONAL_DIR/$name"
    if [ ! -f "$path" ]; then
        echo "optional script not found: $name"
        return 1
    fi
    run_script "$path"
}

declare -A RAN_OPTIONAL=()

if [ "$OPTIONAL_RUN" = "all" ]; then
    echo "optional: running all"
    for script in "$OPTIONAL_DIR"/*.sh; do
        [ -f "$script" ] || continue
        run_script "$script"
        RAN_OPTIONAL["$(basename "$script")"]=1
    done
elif [ -n "$OPTIONAL_RUN" ]; then
    echo "optional: running listed scripts"
    for name in $OPTIONAL_RUN; do
        run_optional_named "$name"
        RAN_OPTIONAL["$name"]=1
    done
fi

if is_yes "$OPTIONAL_PROMPT"; then
    echo "optional: prompt for remaining scripts (default n)"
    for script in "$OPTIONAL_DIR"/*.sh; do
        [ -f "$script" ] || continue
        base="$(basename "$script")"
        if [ "${RAN_OPTIONAL[$base]:-}" = "1" ]; then
            continue
        fi
        # default n
        read -r -p "run $base? [y/N] " ans || ans=n
        case "${ans:-n}" in
            y|Y|yes|YES)
                run_script "$script"
                ;;
            *)
                echo "skipping $base"
                ;;
        esac
    done
fi

echo "done. you should reboot now."
