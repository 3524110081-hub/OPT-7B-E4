#!/usr/bin/env bash

set -euo pipefail

echo "===> Aplicando datos seed..."

if ! compgen -G "db/seed/*.sql" > /dev/null; then
  echo "No se encontraron datos seed."
  exit 0
fi

for seed in db/seed/*.sql; do
    echo "Aplicando datos seed: $seed"

    docker compose exec -T postgres \
        psql \
        -U "${POSTGRES_USER:-cdrl_dev}" \
        -d "${POSTGRES_DB:-cdrl}" \
        -v ON_ERROR_STOP=1 \
        -f - < "$seed"

done

echo "===> Datos seed aplicados correctamente."