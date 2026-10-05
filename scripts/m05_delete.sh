#!/usr/bin/env bash
set -euo pipefail

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-dummy}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-dummy}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_PAGER=""

ENDPOINT="${DYNAMODB_ENDPOINT:-http://127.0.0.1:8000}"
TABLE="cdrl_events"

echo "===> M05 DELETE: eliminando EVT-004..."

aws dynamodb delete-item \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --key '{
        "eventId": {"S": "EVT-004"}
    }' \
    --condition-expression "attribute_exists(eventId)" \
    --return-values ALL_OLD

echo ""
echo "PASS - EVT-004 eliminado correctamente."