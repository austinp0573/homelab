#!/bin/bash

set -a
. ./.env
set +a

envsubst '${FLATNOTES_PASSWD} ${FLATNOTES_SECRET_KEY} ${FLATNOTES_USER} ${FLATNOTES_HOST_PORT} $' < compose.yml.tmpl > compose.yml
