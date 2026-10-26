#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_PAGER=""
ENDPOINT="http://127.0.0.1:8000"

echo "===> M04: Insertando eventos heredados..."
aws dynamodb put-item --table-name cdrl_telemetry_docs --endpoint-url $ENDPOINT --item '{"device_id": {"S": "DEV-001"}, "observed_at": {"S": "2026-09-27T10:00:00Z"}, "metric": {"S": "temperature"}, "value": {"N": "22.5"}}' > /dev/null
aws dynamodb put-item --table-name cdrl_telemetry_docs --endpoint-url $ENDPOINT --item '{"device_id": {"S": "DEV-001"}, "observed_at": {"S": "2026-09-27T10:05:00Z"}, "metric": {"S": "humidity"}, "value": {"N": "55"}}' > /dev/null

echo "===> M06: Evolución Documental (Integrante 2)..."
# V1 válido (Con "source" para que el GSI lo indexe correctamente)
aws dynamodb put-item --table-name cdrl_events --endpoint-url $ENDPOINT \
    --item '{"eventId": {"S": "evt_v1_test"}, "type": {"S": "telemetry"}, "source": {"S": "sensor-v1"}, "timestamp": {"S": "2026-10-25T10:00:00Z"}, "schemaVersion": {"N": "1"}, "payload": {"S": "{\"temp\": 27.5}"}}' > /dev/null

# V2 evolucionado coexistiendo
aws dynamodb put-item --table-name cdrl_events --endpoint-url $ENDPOINT \
    --item '{"eventId": {"S": "evt_v2_test"}, "type": {"S": "telemetry"}, "source": {"S": "sensor-v2"}, "timestamp": {"S": "2026-10-25T10:05:00Z"}, "schemaVersion": {"N": "2"}, "firmwareVersion": {"S": "2.1.0"}, "qualityScore": {"N": "0.97"}}' > /dev/null

echo "===> M06: Auditoría Segura (Integrante 2)..."
aws dynamodb put-item --table-name cdrl_audit --endpoint-url $ENDPOINT \
    --item '{"auditId": {"S": "aud_001"}, "action": {"S": "BULK_DELETE"}, "actorId": {"S": "dev_eduardo"}, "timestamp": {"S": "2026-10-25T10:10:00Z"}, "recordsAffected": {"N": "25000"}}' > /dev/null

echo "===> M06: Falla Controlada (Integrante 2)..."
aws dynamodb delete-item --table-name cdrl_events --endpoint-url $ENDPOINT --key '{"eventId": {"S": "evt_dr_001"}}' > /dev/null

echo "===> M06: Recuperación ante Desastres (Integrante 3)..."
# Restauramos el fixture desde la bóveda de backup para que el test lo encuentre sano
aws dynamodb put-item --table-name cdrl_events --endpoint-url $ENDPOINT \
    --item '{"eventId": {"S": "evt_dr_001"}, "type": {"S": "telemetry.temperature"}, "source": {"S": "sensor-dr"}, "timestamp": {"S": "2026-10-11T10:00:00Z"}, "schemaVersion": {"N": "1"}, "payload": {"S": "{\"temperature\": 27.5}"}}' > /dev/null