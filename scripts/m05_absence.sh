#!/usr/bin/env bash
set -euo pipefail

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-dummy}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-dummy}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_PAGER=""

ENDPOINT="${DYNAMODB_ENDPOINT:-http://127.0.0.1:8000}"
TABLE="cdrl_events"

echo "========================================"
echo " M05 - Manejo de ausencia"
echo "========================================"

echo ""
echo "[1] Consultando evento inexistente..."

RESULT=$(aws dynamodb get-item \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --key '{"eventId":{"S":"EVT-NO-EXISTE"}}' \
    --query "Item" \
    --output text)

if [ "$RESULT" = "None" ] || [ -z "$RESULT" ]; then
    echo "PASS - Evento inexistente manejado correctamente."
else
    echo "FAIL - Se obtuvo un resultado inesperado."
    exit 1
fi

echo ""
echo "[2] Intentando actualizar evento inexistente..."

if aws dynamodb update-item \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --key '{"eventId":{"S":"EVT-NO-EXISTE"}}' \
    --update-expression "SET #value = :value" \
    --expression-attribute-names '{"#value":"value"}' \
    --expression-attribute-values '{":value":{"N":"99"}}' \
    --condition-expression "attribute_exists(eventId)" \
    > /dev/null 2>&1; then

    echo "FAIL - Se permitio actualizar un evento inexistente."
    exit 1
else
    echo "PASS - Actualizacion de evento inexistente rechazada."
fi

echo ""
echo "[3] Intentando eliminar evento inexistente..."

if aws dynamodb delete-item \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --key '{"eventId":{"S":"EVT-NO-EXISTE"}}' \
    --condition-expression "attribute_exists(eventId)" \
    > /dev/null 2>&1; then

    echo "FAIL - Se permitio eliminar un evento inexistente."
    exit 1
else
    echo "PASS - Eliminacion de evento inexistente rechazada."
fi

echo ""
echo "===> Manejo de ausencia completado."