#!/usr/bin/env bash
set -euo pipefail

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-dummy}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-dummy}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_PAGER=""

ENDPOINT="${DYNAMODB_ENDPOINT:-http://127.0.0.1:8000}"
TABLE="cdrl_events"

echo "===> M05: Cargando fixtures sinteticos..."

aws dynamodb put-item \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --item '{
        "eventId": {"S": "EVT-001"},
        "type": {"S": "temperature"},
        "source": {"S": "DEV-001"},
        "timestamp": {"S": "2026-10-04T18:00:00Z"},
        "value": {"N": "22.5"},
        "unit": {"S": "celsius"}
    }'

aws dynamodb put-item \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --item '{
        "eventId": {"S": "EVT-002"},
        "type": {"S": "humidity"},
        "source": {"S": "DEV-001"},
        "timestamp": {"S": "2026-10-04T18:05:00Z"},
        "value": {"N": "55"},
        "unit": {"S": "percent"}
    }'

aws dynamodb put-item \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --item '{
        "eventId": {"S": "EVT-003"},
        "type": {"S": "temperature"},
        "source": {"S": "DEV-002"},
        "timestamp": {"S": "2026-10-04T18:10:00Z"},
        "value": {"N": "24.8"},
        "unit": {"S": "celsius"}
    }'

echo "===> Fixtures M05 cargados correctamente."