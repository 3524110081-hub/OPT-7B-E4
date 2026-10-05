#!/usr/bin/env bash
set -euo pipefail

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-dummy}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-dummy}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_PAGER=""

ENDPOINT="${DYNAMODB_ENDPOINT:-http://127.0.0.1:8000}"
TABLE="cdrl_events"

echo "===> M05 CREATE: creando EVT-004..."

aws dynamodb put-item \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --item '{
        "eventId": {"S": "EVT-004"},
        "type": {"S": "pressure"},
        "source": {"S": "DEV-003"},
        "timestamp": {"S": "2026-10-04T18:15:00Z"},
        "value": {"N": "1012.8"},
        "unit": {"S": "hPa"}
    }' \
    --condition-expression "attribute_not_exists(eventId)"

echo "PASS - EVT-004 creado correctamente."