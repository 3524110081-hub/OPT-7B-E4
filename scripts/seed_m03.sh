#!/usr/bin/env bash

set -euo pipefail

echo "===> Aplicando fixture M03 con role_writer..."

# Cargar variables locales si existe .env
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

: "${DB_WRITER_USER:?Falta DB_WRITER_USER}"
: "${DB_WRITER_PASSWORD:?Falta DB_WRITER_PASSWORD}"
: "${POSTGRES_DB:?Falta POSTGRES_DB}"

docker compose exec -T \
    -e PGPASSWORD="${DB_WRITER_PASSWORD}" \
    postgres \
    psql \
    -U "${DB_WRITER_USER}" \
    -d "${POSTGRES_DB}" \
    -v ON_ERROR_STOP=1 \
    -f /dev/stdin \
    < db/seed/003_m03_role_fixtures.sql

echo "===> Fixture M03 aplicado correctamente con ${DB_WRITER_USER}."