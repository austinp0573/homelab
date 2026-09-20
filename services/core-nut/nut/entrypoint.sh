#!/bin/sh
set -eu

mkdir -p /run/nut /etc/nut
chown nut:nut /run/nut
chmod 0755 /run/nut

if [ -f /config/ups.conf ]; then
    cp /config/ups.conf /etc/nut/ups.conf
    cp /config/upsd.conf /etc/nut/upsd.conf
    cp /config/upsd.users /etc/nut/upsd.users

    chown root:nut \
        /etc/nut/ups.conf \
        /etc/nut/upsd.conf \
        /etc/nut/upsd.users

    chmod 0640 \
        /etc/nut/ups.conf \
        /etc/nut/upsd.conf \
        /etc/nut/upsd.users
fi

if [ "$#" -gt 0 ]; then
    exec "$@"
fi

echo "Starting NUT UPS driver..."
upsdrvctl start

echo "Starting NUT server..."
exec upsd -F
