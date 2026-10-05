#!/usr/bin/env bash
set -euo pipefail

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-dummy}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-dummy}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_PAGER=""

ENDPOINT="${DYNAMODB_ENDPOINT:-http://127.0.0.1:8000}"
TABLE="cdrl_events"

echo "===> M05 UPDATE: actualizando EVT-001..."

aws dynamodb update-item \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --key '{
        "eventId": {"S": "EVT-001"}
    }' \
    --update-expression "SET #value = :value" \
    --expression-attribute-names '{
        "#value": "value"
    }' \
    --expression-attribute-values '{
        ":value": {"N": "23.5"}
    }' \
    --condition-expression "attribute_exists(eventId)" \
    --return-values ALL_NEW

echo ""
echo "PASS - EVT-001 actualizado correctamente."