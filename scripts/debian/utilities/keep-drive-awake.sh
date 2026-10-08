#!/usr/bin/bash

# use: <sudo /tmp/hdd-keepalive.sh /dev/sdb 30>

DISK="${1:?Usage: $0 /dev/sdX}"
INTERVAL="${2:-30}"

while true; do
    if ! dd \
        if="$DISK" \
        of=/dev/null \
        bs=1M \
        count=1 \
        iflag=direct \
        status=none
    then
        printf 'WARNING: keepalive read failed at %s\n' "$(date)" >&2
    fi

    sleep "$INTERVAL"
done