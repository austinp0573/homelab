#!/bin/bash

set -a
. ./.env
set +a

envsubst '${POSTGRES_USER} ${POSTGRES_PASSWORD} ${POSTGRES_DATABASE} ${JOPLIN_SERVER_HOST_PORT} ${JOPLIN_APP_PORT} ${APP_BASE_URL} ${POSTGRES_PORT}' < compose.yml.tmpl > compose.yml
