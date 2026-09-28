#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_PAGER=""
ENDPOINT="http://127.0.0.1:8000"

echo "1. Insertando eventos continuos con esquemas flexibles (H1)..."
aws dynamodb put-item --table-name cdrl_telemetry_docs --endpoint-url $ENDPOINT \
    --item '{"device_id": {"S": "DEV-001"}, "observed_at": {"S": "2026-09-27T10:00:00Z"}, "metric": {"S": "temperature"}, "value": {"N": "22.5"}}'

aws dynamodb put-item --table-name cdrl_telemetry_docs --endpoint-url $ENDPOINT \
    --item '{"device_id": {"S": "DEV-001"}, "observed_at": {"S": "2026-09-27T10:05:00Z"}, "metric": {"S": "humidity"}, "value": {"N": "55"}, "extra_field": {"S": "sensor_calibrated"}}'

echo "2. Consulta: Eventos de un dispositivo en un intervalo..."
aws dynamodb query --table-name cdrl_telemetry_docs --endpoint-url $ENDPOINT \
    --key-condition-expression "device_id = :d AND observed_at BETWEEN :start AND :end" \
    --expression-attribute-values '{":d":{"S":"DEV-001"}, ":start":{"S":"2026-09-27T10:00:00Z"}, ":end":{"S":"2026-09-27T10:10:00Z"}}'

echo "3. Consulta: Ultimos eventos..."
aws dynamodb query --table-name cdrl_telemetry_docs --endpoint-url $ENDPOINT \
    --key-condition-expression "device_id = :d" \
    --expression-attribute-values '{":d":{"S":"DEV-001"}}' \
    --no-scan-index-forward \
    --limit 1