#!/usr/bin/env bash

set -euo pipefail

DB_USER="${POSTGRES_USER:-cdrl_dev}"
DB_NAME="${POSTGRES_DB:-cdrl}"

DB=(docker compose exec -T postgres psql \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -At)

echo "========================================"
echo " M01 - Pruebas de Seed y Telemetría"
echo "========================================"

echo ""
echo "[1/4] Caso normal"
echo "Verificando que exista el evento CPU del seed..."

normal_count="$("${DB[@]}" -c "
    SELECT COUNT(*)
    FROM telemetry_events
    WHERE metric = 'cpu_usage'
      AND value = 50
      AND unit = '%';
")"

if [ "$normal_count" -ge 1 ]; then
    echo "OK: caso normal aceptado"
else
    echo "ERROR: no se encontró el dato normal del seed"
    exit 1
fi


echo ""
echo "[2/4] Caso límite inferior"
echo "Probando CPU = 0..."

"${DB[@]}" -c "
    INSERT INTO telemetry_events (
        id,
        device_id,
        metric,
        value,
        unit,
        observed_at
    )
    VALUES (
        '00000000-0000-0000-0000-000000000201',
        '00000000-0000-0000-0000-000000000001',
        'cpu_usage',
        0,
        '%',
        '2026-09-01T10:01:00Z'
    )
    ON CONFLICT (id) DO NOTHING;
"

echo "OK: límite inferior aceptado"


echo ""
echo "[3/4] Caso límite superior"
echo "Probando CPU = 100..."

"${DB[@]}" -c "
    INSERT INTO telemetry_events (
        id,
        device_id,
        metric,
        value,
        unit,
        observed_at
    )
    VALUES (
        '00000000-0000-0000-0000-000000000202',
        '00000000-0000-0000-0000-000000000001',
        'cpu_usage',
        100,
        '%',
        '2026-09-01T10:02:00Z'
    )
    ON CONFLICT (id) DO NOTHING;
"

echo "OK: límite superior aceptado"


echo ""
echo "[4/4] Fallo declarado"
echo "Probando CPU = 101..."
echo "El valor debe ser rechazado por la base de datos."

if "${DB[@]}" -c "
    INSERT INTO telemetry_events (
        id,
        device_id,
        metric,
        value,
        unit,
        observed_at
    )
    VALUES (
        '00000000-0000-0000-0000-000000000203',
        '00000000-0000-0000-0000-000000000001',
        'cpu_usage',
        101,
        '%',
        '2026-09-01T10:03:00Z'
    );
" >/dev/null 2>&1; then

    echo "ERROR: el valor 101 fue aceptado"
    exit 1

else

    echo "OK: el valor 101 fue rechazado correctamente"

fi


echo ""
echo "========================================"
echo " M01: TODAS LAS PRUEBAS PASARON"
echo "========================================"