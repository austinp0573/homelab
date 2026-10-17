#!/bin/sh
set -e

mkdir -p /etc/crowdsec/parsers/s02-enrich

if [ -f /whitelist.yaml.template ]; then
  sed "s|\${HOME_IP_CIDR}|${HOME_IP_CIDR:-127.0.0.1/32}|g" /whitelist.yaml.template > /etc/crowdsec/parsers/s02-enrich/whitelist.yaml
elif [ -f /etc/crowdsec/parsers/s02-enrich/whitelist.yaml.template ]; then
  sed "s|\${HOME_IP_CIDR}|${HOME_IP_CIDR:-127.0.0.1/32}|g" /etc/crowdsec/parsers/s02-enrich/whitelist.yaml.template > /etc/crowdsec/parsers/s02-enrich/whitelist.yaml
fi

exec /docker_start.sh "$@"
