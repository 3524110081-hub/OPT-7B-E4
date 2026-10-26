#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_PAGER=""
ENDPOINT="http://127.0.0.1:8000"
TABLE="cdrl_events"

echo "===> Ejecutando Migración de Esquemas y Rollback..."

# 1. Migración de V1 a V2 (Segura e Idempotente)
echo "1. Migrando documento antiguo (evt_mig_001) a V2..."
aws dynamodb update-item --table-name $TABLE --endpoint-url $ENDPOINT \
    --key '{"eventId": {"S": "evt_mig_001"}}' \
    --update-expression "SET schemaVersion = :v2, firmwareVersion = :fw, qualityScore = :qs, #src = :src" \
    --condition-expression "attribute_not_exists(schemaVersion) OR schemaVersion = :v1" \
    --expression-attribute-names '{"#src": "source"}' \
    --expression-attribute-values '{":v2":{"N":"2"}, ":v1":{"N":"1"}, ":fw":{"S":"2.1.0"}, ":qs":{"N":"0.97"}, ":src":{"S":"warehouse"}}' \
    > /dev/null 2>&1 || echo "  -> [INFO] Idempotencia: El documento ya estaba en V2 o no existía."

# 2. Inserción de un documento nativo V2
echo "2. Insertando documento nativo V2 (evt_mig_002)..."
aws dynamodb put-item --table-name $TABLE --endpoint-url $ENDPOINT \
    --item '{"eventId": {"S": "evt_mig_002"}, "type": {"S": "telemetry"}, "timestamp": {"S": "2026-10-25T10:00:00Z"}, "schemaVersion": {"N": "2"}, "firmwareVersion": {"S": "3.0.0"}}' > /dev/null

# 3. Rollback de V2 a V1
echo "3. Ejecutando Rollback del documento evt_mig_002 a V1..."
aws dynamodb update-item --table-name $TABLE --endpoint-url $ENDPOINT \
    --key '{"eventId": {"S": "evt_mig_002"}}' \
    --update-expression "SET schemaVersion = :v1 REMOVE firmwareVersion, qualityScore, #src" \
    --condition-expression "schemaVersion = :v2" \
    --expression-attribute-names '{"#src": "source"}' \
    --expression-attribute-values '{":v1":{"N":"1"}, ":v2":{"N":"2"}}' \
    > /dev/null 2>&1 || echo "  -> [INFO] Idempotencia: El rollback ya se aplicó."

echo "===> Lógica de migración completada."