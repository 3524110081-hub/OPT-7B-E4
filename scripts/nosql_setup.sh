#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_PAGER=""
ENDPOINT="http://127.0.0.1:8000"

echo "===> Configurando Infraestructura (M04, M05 y M06)..."

# --- INFRAESTRUCTURA M04 ---
aws dynamodb delete-table --table-name cdrl_telemetry_docs --endpoint-url $ENDPOINT --region us-east-1 > /dev/null 2>&1 || true
aws dynamodb create-table --table-name cdrl_telemetry_docs \
    --attribute-definitions AttributeName=device_id,AttributeType=S AttributeName=observed_at,AttributeType=S \
    --key-schema AttributeName=device_id,KeyType=HASH AttributeName=observed_at,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST --endpoint-url $ENDPOINT --region us-east-1 > /dev/null

# --- INFRAESTRUCTURA M05 ---
aws dynamodb delete-table --table-name cdrl_events --endpoint-url $ENDPOINT --region us-east-1 > /dev/null 2>&1 || true
aws dynamodb create-table --table-name cdrl_events \
    --attribute-definitions AttributeName=eventId,AttributeType=S AttributeName=type,AttributeType=S AttributeName=source,AttributeType=S AttributeName=timestamp,AttributeType=S \
    --key-schema AttributeName=eventId,KeyType=HASH \
    --global-secondary-indexes \
        "IndexName=TypeTimestampIndex,KeySchema=[{AttributeName=type,KeyType=HASH},{AttributeName=timestamp,KeyType=RANGE}],Projection={ProjectionType=ALL}" \
        "IndexName=SourceTimestampIndex,KeySchema=[{AttributeName=source,KeyType=HASH},{AttributeName=timestamp,KeyType=RANGE}],Projection={ProjectionType=ALL}" \
    --billing-mode PAY_PER_REQUEST --endpoint-url $ENDPOINT --region us-east-1 > /dev/null

# --- INFRAESTRUCTURA M06: Auditoría y Respaldo ---
aws dynamodb delete-table --table-name cdrl_audit --endpoint-url $ENDPOINT --region us-east-1 > /dev/null 2>&1 || true
aws dynamodb create-table --table-name cdrl_audit \
    --attribute-definitions AttributeName=auditId,AttributeType=S \
    --key-schema AttributeName=auditId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST --endpoint-url $ENDPOINT --region us-east-1 > /dev/null

aws dynamodb delete-table --table-name cdrl_events_backup --endpoint-url $ENDPOINT --region us-east-1 > /dev/null 2>&1 || true
aws dynamodb create-table --table-name cdrl_events_backup \
    --attribute-definitions AttributeName=eventId,AttributeType=S \
    --key-schema AttributeName=eventId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST --endpoint-url $ENDPOINT --region us-east-1 > /dev/null

# --- INYECCIÓN DE FIXTURES M06 ---
echo "===> M06: Inyectando documento v1 en tabla viva y en bóveda de respaldo..."
# Simulamos un documento de telemetría antiguo (v1)
DOC_V1='{"eventId": {"S": "evt_dr_001"}, "type": {"S": "telemetry.temperature"}, "source": {"S": "sensor-dr"}, "timestamp": {"S": "2026-10-11T10:00:00Z"}, "schemaVersion": {"N": "1"}, "payload": {"S": "{\"temperature\": 27.5}"}}'

# Guardar en producción
aws dynamodb put-item --table-name cdrl_events --endpoint-url $ENDPOINT --region us-east-1 --item "$DOC_V1"
# Guardar en el backup (simulando que el backup automático lo respaldó hace 40 minutos)
aws dynamodb put-item --table-name cdrl_events_backup --endpoint-url $ENDPOINT --region us-east-1 --item "$DOC_V1"

echo "===> M07: preparando el estado base heredado v1..."
bash scripts/m07_seed_legacy.sh

echo "===> Infraestructura preparada exitosamente."
