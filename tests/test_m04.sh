#!/usr/bin/env bash
set -euo pipefail

export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_PAGER=""

ENDPOINT="http://127.0.0.1:8000"
TABLE="cdrl_telemetry_docs"

echo "========================================"
echo " M04 - Pruebas NoSQL"
echo "========================================"

echo ""
echo "[1/5] Caso normal - eventos de DEV-001"

COUNT=$(aws dynamodb query \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --key-condition-expression "device_id = :d" \
    --expression-attribute-values \
    '{":d":{"S":"DEV-001"}}' \
    --select COUNT \
    --query Count \
    --output text)

if [ "$COUNT" -eq 2 ]; then
    echo "PASS - DEV-001 contiene 2 eventos"
else
    echo "FAIL - Se esperaban 2 eventos y se obtuvieron $COUNT"
    exit 1
fi


echo ""
echo "[2/5] Caso limite 1 - intervalo con un solo evento"

COUNT=$(aws dynamodb query \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --key-condition-expression \
    "device_id = :d AND observed_at BETWEEN :start AND :end" \
    --expression-attribute-values \
    '{":d":{"S":"DEV-001"},":start":{"S":"2026-09-27T10:00:00Z"},":end":{"S":"2026-09-27T10:00:00Z"}}' \
    --select COUNT \
    --query Count \
    --output text)

if [ "$COUNT" -eq 1 ]; then
    echo "PASS - Se obtuvo exactamente 1 evento"
else
    echo "FAIL - Se esperaba 1 evento y se obtuvieron $COUNT"
    exit 1
fi


echo ""
echo "[3/5] Caso limite 2 - dispositivo inexistente"

COUNT=$(aws dynamodb query \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --key-condition-expression "device_id = :d" \
    --expression-attribute-values \
    '{":d":{"S":"DEV-NO-EXISTE"}}' \
    --select COUNT \
    --query Count \
    --output text)

if [ "$COUNT" -eq 0 ]; then
    echo "PASS - Dispositivo inexistente devuelve 0 eventos"
else
    echo "FAIL - Se esperaban 0 eventos"
    exit 1
fi


echo ""
echo "[4/5] Fallo declarado - evento sin claves obligatorias"

if aws dynamodb put-item \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --item '{"metric":{"S":"temperature"},"value":{"N":"25"}}' \
    > /dev/null 2>&1; then

    echo "FAIL - DynamoDB acepto un evento invalido"
    exit 1
else
    echo "PASS - DynamoDB rechazo correctamente el evento invalido"
fi


echo ""
echo "[5/5] Consulta representativa - metric=temperature"

COUNT=$(aws dynamodb scan \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --filter-expression "metric = :m" \
    --expression-attribute-values \
    '{":m":{"S":"temperature"}}' \
    --select COUNT \
    --query Count \
    --output text)

if [ "$COUNT" -eq 1 ]; then
    echo "PASS - Se encontro 1 evento temperature"
else
    echo "FAIL - Se esperaba 1 evento temperature y se obtuvieron $COUNT"
    exit 1
fi


echo ""
echo "========================================"
echo " M04: TODAS LAS PRUEBAS PASARON"
echo "========================================"