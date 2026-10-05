#!/usr/bin/env bash
set -euo pipefail

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-dummy}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-dummy}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_PAGER=""

ENDPOINT="${DYNAMODB_ENDPOINT:-http://127.0.0.1:8000}"
TABLE="cdrl_events"

echo "========================================"
echo " M05 - Operaciones READ"
echo "========================================"

echo ""
echo "[1] Buscar evento por eventId..."

aws dynamodb get-item \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --key '{
        "eventId": {"S": "EVT-001"}
    }'

echo ""
echo "[2] Consultar por tipo y rango temporal usando TypeTimestampIndex..."

aws dynamodb query \
    --table-name "$TABLE" \
    --index-name "TypeTimestampIndex" \
    --endpoint-url "$ENDPOINT" \
    --key-condition-expression "#type = :type AND #ts BETWEEN :start AND :end" \
    --expression-attribute-names '{
        "#type": "type",
        "#ts": "timestamp"
    }' \
    --expression-attribute-values '{
        ":type": {"S": "temperature"},
        ":start": {"S": "2026-10-04T18:00:00Z"},
        ":end": {"S": "2026-10-04T19:00:00Z"}
    }'

echo ""
echo "[3] Consultar por dispositivo y tiempo usando SourceTimestampIndex..."

aws dynamodb query \
    --table-name "$TABLE" \
    --index-name "SourceTimestampIndex" \
    --endpoint-url "$ENDPOINT" \
    --key-condition-expression "#source = :source AND #ts BETWEEN :start AND :end" \
    --expression-attribute-names '{
        "#source": "source",
        "#ts": "timestamp"
    }' \
    --expression-attribute-values '{
        ":source": {"S": "DEV-001"},
        ":start": {"S": "2026-10-04T18:00:00Z"},
        ":end": {"S": "2026-10-04T19:00:00Z"}
    }'

echo ""
echo "===> Operaciones READ completadas."