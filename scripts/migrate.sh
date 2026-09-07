#!/usr/bin/env bash

set -euo pipefail

echo "===> Aplicando migracciones..."

if ! compgen -G "db/migrations/*.sql" > /dev/null; then
  echo "No se encontraron migraciones."
  exit 0
fi

for migration in db/migrations/*.sql; do
    echo "Aplicando migración: $migration"

    docker compose exec -T postgres \
        psql \
        -U "${POSTGRES_USER:-cdrl_dev}" \
        -d "${POSTGRES_DB:-cdrl}" \
        -v ON_ERROR_STOP=1 \
        -f - < "$migration"

done

echo "===> Migraciones aplicadas correctamente."