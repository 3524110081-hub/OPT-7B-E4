#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_PAGER=""
ENDPOINT="http://127.0.0.1:8000"

echo "===> M04: Insertando eventos heredados para retrocompatibilidad..."
aws dynamodb put-item --table-name cdrl_telemetry_docs --endpoint-url $ENDPOINT \
    --item '{"device_id": {"S": "DEV-001"}, "observed_at": {"S": "2026-09-27T10:00:00Z"}, "metric": {"S": "temperature"}, "value": {"N": "22.5"}}'

aws dynamodb put-item --table-name cdrl_telemetry_docs --endpoint-url $ENDPOINT \
    --item '{"device_id": {"S": "DEV-001"}, "observed_at": {"S": "2026-09-27T10:05:00Z"}, "metric": {"S": "humidity"}, "value": {"N": "55"}, "extra_field": {"S": "sensor_calibrated"}}'

# Consultas legacy silenciadas para no ensuciar la salida
aws dynamodb query --table-name cdrl_telemetry_docs --endpoint-url $ENDPOINT \
    --key-condition-expression "device_id = :d AND observed_at BETWEEN :start AND :end" \
    --expression-attribute-values '{":d":{"S":"DEV-001"}, ":start":{"S":"2026-09-27T10:00:00Z"}, ":end":{"S":"2026-09-27T10:10:00Z"}}' > /dev/null

echo ""
echo "========================================"
echo " M05 - Almacen documental de eventos"
echo "========================================"

echo ""
echo "[1/7] Cargando fixtures..."
bash scripts/m05_seed.sh

echo ""
echo "[2/7] CREATE..."
bash scripts/m05_create.sh

echo ""
echo "[3/7] Duplicado..."
bash scripts/m05_duplicate.sh

echo ""
echo "[4/7] READ..."
bash scripts/m05_read.sh

echo ""
echo "[5/7] UPDATE..."
bash scripts/m05_update.sh

echo ""
echo "[6/7] DELETE..."
bash scripts/m05_delete.sh

echo ""
echo "[7/7] Manejo de ausencia..."
bash scripts/m05_absence.sh

echo ""
echo "========================================"
echo " M05 - CRUD completado correctamente"
echo "========================================"