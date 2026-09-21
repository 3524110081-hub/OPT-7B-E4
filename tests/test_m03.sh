#!/usr/bin/env bash

set -euo pipefail

DB_USER="${POSTGRES_USER:-cdrl_dev}"
DB_NAME="${POSTGRES_DB:-cdrl}"

ROLE_READER="role_reader"
ROLE_WRITER="role_writer"
ROLE_OPERATOR="role_operator"
ROLE_MIGRATOR="role_migrator"

DB=(docker compose exec -T postgres psql \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -qAt)

echo "========================================"
echo " M03 - Seguridad y minimo privilegio"
echo "========================================"

# =========================================================
# 1. CASO NORMAL
# role_reader puede realizar SELECT
# =========================================================

echo ""
echo "[1/9] Caso normal: reader puede hacer SELECT"

reader_result="$("${DB[@]}" -c "
    SET ROLE $ROLE_READER;
    SELECT COUNT(*) FROM devices;
    RESET ROLE;
")"

if [[ "$reader_result" =~ ^[0-9]+$ ]]; then
    echo "PASS: role_reader puede consultar devices"
else
    echo "FAIL: role_reader no pudo consultar devices"
    exit 1
fi


# =========================================================
# 2. CASO LIMITE 1
# Writer puede insertar
# =========================================================

echo ""
echo "[2/9] Caso limite 1: writer puede hacer INSERT"

TEST_ID="88888888-8888-8888-8888-888888888888"

# Limpieza preventiva como administrador
"${DB[@]}" -c "
    DELETE FROM devices
    WHERE id = '$TEST_ID';
" >/dev/null 2>&1 || true

if "${DB[@]}" -c "
    SET ROLE $ROLE_WRITER;

    INSERT INTO devices (
        id,
        device_uid,
        device_type
    )
    VALUES (
        '$TEST_ID',
        'M03-WRITER-TEST',
        'TEST'
    );

    RESET ROLE;
" >/dev/null 2>&1; then

    echo "PASS: role_writer puede insertar"

else
    echo "FAIL: role_writer no pudo realizar INSERT"
    exit 1
fi

# Limpieza
"${DB[@]}" -c "
    DELETE FROM devices
    WHERE id = '$TEST_ID';
" >/dev/null 2>&1 || true


# =========================================================
# 3. CASO LIMITE 2
# Operator solo puede consultar devices
# =========================================================

echo ""
echo "[3/9] Caso limite 2: operator puede consultar devices"

operator_result="$("${DB[@]}" -c "
    SET ROLE $ROLE_OPERATOR;
    SELECT COUNT(*) FROM devices;
    RESET ROLE;
")"

if [[ "$operator_result" =~ ^[0-9]+$ ]]; then
    echo "PASS: role_operator puede consultar devices"
else
    echo "FAIL: role_operator no pudo consultar devices"
    exit 1
fi


# =========================================================
# 4. NEGATIVA 1
# Reader NO puede insertar
# =========================================================

echo ""
echo "[4/9] Negativa 1: reader intenta INSERT"

if "${DB[@]}" -c "
    SET ROLE $ROLE_READER;

    INSERT INTO devices (
        id,
        device_uid,
        device_type
    )
    VALUES (
        '99999999-9999-9999-9999-999999999991',
        'DENIED-READER',
        'TEST'
    );
" >/dev/null 2>&1; then

    echo "FAIL: role_reader pudo realizar INSERT"
    exit 1

else
    echo "PASS: INSERT correctamente denegado a role_reader"
fi


# =========================================================
# 5. NEGATIVA 2
# Reader NO puede actualizar
# =========================================================

echo ""
echo "[5/9] Negativa 2: reader intenta UPDATE"

if "${DB[@]}" -c "
    SET ROLE $ROLE_READER;

    UPDATE devices
    SET device_type = 'FORBIDDEN'
    WHERE id = '55555555-5555-5555-5555-555555555551';
" >/dev/null 2>&1; then

    echo "FAIL: role_reader pudo realizar UPDATE"
    exit 1

else
    echo "PASS: UPDATE correctamente denegado a role_reader"
fi


# =========================================================
# 6. NEGATIVA 3
# Writer NO puede cambiar el esquema
# =========================================================

echo ""
echo "[6/9] Negativa 3: writer intenta ALTER TABLE"

if "${DB[@]}" -c "
    SET ROLE $ROLE_WRITER;

    ALTER TABLE devices
    ADD COLUMN forbidden_m03_column TEXT;
" >/dev/null 2>&1; then

    echo "FAIL: role_writer pudo realizar ALTER TABLE"

    "${DB[@]}" -c "
        ALTER TABLE devices
        DROP COLUMN IF EXISTS forbidden_m03_column;
    " >/dev/null 2>&1 || true

    exit 1

else
    echo "PASS: ALTER TABLE correctamente denegado a role_writer"
fi


# =========================================================
# 7. NEGATIVA 4 / FALLO DECLARADO
# Operator no tiene acceso a telemetry_events
# =========================================================

echo ""
echo "[7/9] Fallo declarado: operator intenta acceder a telemetry_events"

if "${DB[@]}" -c "
    SET ROLE $ROLE_OPERATOR;
    SELECT COUNT(*) FROM telemetry_events;
" >/dev/null 2>&1; then

    echo "FAIL: role_operator pudo consultar telemetry_events"
    exit 1

else
    echo "PASS: acceso a telemetry_events correctamente denegado"
fi


# =========================================================
# 8. SECRETOS
# .env no debe estar versionado
# =========================================================

echo ""
echo "[8/9] Verificando secretos versionados"

if git ls-files --error-unmatch .env >/dev/null 2>&1; then
    echo "FAIL: .env esta versionado en Git"
    exit 1
else
    echo "PASS: .env no esta versionado"
fi

# =========================================================
# 9. ROLE MIGRATOR
# Debe poder crear y eliminar objetos de esquema
# =========================================================

echo ""
echo "[9/9] Migrator puede realizar operaciones de migracion"

if "${DB[@]}" -c "
    SET ROLE $ROLE_MIGRATOR;

    CREATE TABLE m03_migration_test (
        id INTEGER PRIMARY KEY
    );

    DROP TABLE m03_migration_test;

    RESET ROLE;
" >/dev/null 2>&1; then

    echo "PASS: role_migrator puede realizar operaciones de migracion"

else
    echo "FAIL: role_migrator no pudo realizar operaciones de migracion"
    exit 1
fi


echo ""
echo "========================================"
echo " M03: TODAS LAS PRUEBAS PASARON"
echo "========================================"