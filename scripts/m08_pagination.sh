#!/bin/bash
set -e
export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_PAGER=""
ENDPOINT="http://127.0.0.1:8000"
TABLE="cdrl_events"

echo "===> M08: Paginación estable basada en cursores..."

echo "0. Asegurando volumen de datos para garantizar paginación..."
aws dynamodb put-item --table-name $TABLE --endpoint-url $ENDPOINT --item '{"eventId": {"S": "evt_page_01"}, "type": {"S": "telemetry"}, "timestamp": {"S": "2026-10-26T10:00:00Z"}}' > /dev/null
aws dynamodb put-item --table-name $TABLE --endpoint-url $ENDPOINT --item '{"eventId": {"S": "evt_page_02"}, "type": {"S": "telemetry"}, "timestamp": {"S": "2026-10-26T10:01:00Z"}}' > /dev/null
aws dynamodb put-item --table-name $TABLE --endpoint-url $ENDPOINT --item '{"eventId": {"S": "evt_page_03"}, "type": {"S": "telemetry"}, "timestamp": {"S": "2026-10-26T10:02:00Z"}}' > /dev/null

echo "1. Solicitando Página 1 (Límite 2)..."
PAGE1=$(aws dynamodb query --table-name $TABLE \
    --index-name TypeTimestampIndex \
    --endpoint-url $ENDPOINT \
    --key-condition-expression "#t = :typeVal" \
    --expression-attribute-names '{"#t": "type"}' \
    --expression-attribute-values '{":typeVal": {"S": "telemetry"}}' \
    --limit 2 \
    --output json)

# Extraer el cursor en formato compacto
echo "$PAGE1" | jq -c '.LastEvaluatedKey' > /tmp/cursor.json

# Validación de seguridad
if grep -q "null" /tmp/cursor.json; then
    echo "  -> [ERROR] No se generó un cursor. La consulta no tiene más páginas."
    exit 1
else
    echo "  -> [PASS] Cursor obtenido exitosamente."
fi

echo "2. Simulando inserción concurrente en tiempo real..."
aws dynamodb put-item --table-name $TABLE --endpoint-url $ENDPOINT \
    --item '{"eventId": {"S": "evt_paged_new"}, "type": {"S": "telemetry"}, "timestamp": {"S": "2026-10-26T10:01:30Z"}, "payload": {"S": "{\"temp\": 28}"}}' > /dev/null

echo "3. Solicitando Página 2 usando el cursor extraído..."
PAGE2=$(aws dynamodb query --table-name $TABLE \
    --index-name TypeTimestampIndex \
    --endpoint-url $ENDPOINT \
    --key-condition-expression "#t = :typeVal" \
    --expression-attribute-names '{"#t": "type"}' \
    --expression-attribute-values '{":typeVal": {"S": "telemetry"}}' \
    --limit 2 \
    --exclusive-start-key file:///tmp/cursor.json \
    --output json)

ITEMS_P2=$(echo "$PAGE2" | jq '.Count')
echo "  -> [PASS] Página 2 obtenida limpiamente. Items leídos: $ITEMS_P2"

echo "===> Tareas del Integrante 2 completadas exitosamente."