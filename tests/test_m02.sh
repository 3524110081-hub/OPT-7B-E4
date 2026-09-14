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
echo " M02 - Pruebas del modelo relacional"
echo "========================================"

# ---------------------------------------------------------
# 1. CASO NORMAL
# ---------------------------------------------------------

echo ""
echo "[1/5] Caso normal"
echo "Verificando dispositivo con telemetria..."

normal_result="$("${DB[@]}" -c "
    SELECT COUNT(*)
    FROM devices d
    JOIN telemetry_events t ON d.id = t.device_id
    WHERE d.id = '55555555-5555-5555-5555-555555555551'
      AND d.device_uid = 'SENSOR-TEMP-02'
      AND d.device_type = 'THERMOSTAT'
      AND t.metric = 'temperature'
      AND t.unit = 'celsius'
      AND t.value = 25.0;
")"

if [ "$normal_result" -ge 1 ]; then
    echo "PASS: caso normal correcto"
else
    echo "FAIL: no se encontro el caso normal esperado"
    exit 1
fi


# ---------------------------------------------------------
# 2. CASO VACÍO
# ---------------------------------------------------------

echo ""
echo "[2/5] Caso vacio"
echo "Verificando dispositivo sin eventos de telemetria..."

empty_result="$("${DB[@]}" -c "
    SELECT COUNT(*)
    FROM telemetry_events
    WHERE device_id = '55555555-5555-5555-5555-555555555552';
")"

if [ "$empty_result" -eq 0 ]; then
    echo "PASS: caso vacio correcto"
else
    echo "FAIL: el dispositivo deberia no tener telemetria"
    exit 1
fi


# ---------------------------------------------------------
# 3. CASO LÍMITE
# ---------------------------------------------------------

echo ""
echo "[3/5] Caso limite"
echo "Verificando cadenas no vacias de longitud minima..."

boundary_result="$("${DB[@]}" -c "
    SELECT COUNT(*)
    FROM devices d
    JOIN telemetry_events t ON d.id = t.device_id
    WHERE d.id = '55555555-5555-5555-5555-555555555553'
      AND d.device_uid = 'X'
      AND d.device_type = 'Y'
      AND t.metric = 'Z'
      AND t.unit = 'W'
      AND t.value = 10.5;
")"

if [ "$boundary_result" -ge 1 ]; then
    echo "PASS: caso limite aceptado"
else
    echo "FAIL: no se encontro el caso limite"
    exit 1
fi


# ---------------------------------------------------------
# 4. CONSULTA PARAMETRIZADA
# ---------------------------------------------------------

echo ""
echo "[4/5] Consulta parametrizada"
echo "Verificando PREPARE y EXECUTE..."

parameterized_result="$("${DB[@]}" <<'SQL'
PREPARE verify_device_telemetry (uuid) AS
    SELECT COUNT(*)
    FROM devices d
    LEFT JOIN telemetry_events t ON d.id = t.device_id
    WHERE d.id = $1;

EXECUTE verify_device_telemetry(
    '55555555-5555-5555-5555-555555555551'
);
SQL
)"

if echo "$parameterized_result" | grep -Eq '(^|[^0-9])1([^0-9]|$)'; then
    echo "PASS: consulta parametrizada ejecutada correctamente"
else
    echo "FAIL: la consulta parametrizada no devolvio el resultado esperado"
    exit 1
fi


# ---------------------------------------------------------
# 5. FALLO DECLARADO
# ---------------------------------------------------------

echo ""
echo "[5/5] Fallo declarado"
echo "Intentando insertar device_uid vacio..."

TEST_DEVICE_ID="77777777-7777-7777-7777-777777777777"

# Limpieza preventiva
"${DB[@]}" -c "
    DELETE FROM devices
    WHERE id = '$TEST_DEVICE_ID';
" >/dev/null 2>&1 || true

if "${DB[@]}" -c "
    INSERT INTO devices (
        id,
        device_uid,
        device_type
    )
    VALUES (
        '$TEST_DEVICE_ID',
        '',
        'TEST'
    );
" >/dev/null 2>&1; then

    echo "FAIL: PostgreSQL acepto un device_uid vacio"

    "${DB[@]}" -c "
        DELETE FROM devices
        WHERE id = '$TEST_DEVICE_ID';
    " >/dev/null 2>&1 || true

    exit 1
else
    echo "PASS: PostgreSQL rechazo correctamente el dato invalido"
fi


echo ""
echo "========================================"
echo " M02: TODAS LAS PRUEBAS PASARON"
echo "========================================"