#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_PAGER=""

ENDPOINT="http://127.0.0.1:8000"
TABLE="cdrl_events"
FIXTURE="fixtures/m07-legacy-v1-batch.json"

echo "===> M07: comprobando DynamoDB Local..."

if ! aws dynamodb describe-table \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --region "$AWS_DEFAULT_REGION" >/dev/null 2>&1; then
    echo "ERROR: no existe $TABLE. Ejecuta primero el setup de DynamoDB."
    exit 1
fi

echo "===> M07: cargando documentos heredados v1..."

response="$(aws dynamodb batch-write-item \
    --request-items "file://$FIXTURE" \
    --endpoint-url "$ENDPOINT" \
    --region "$AWS_DEFAULT_REGION")"

python3 -c '
import json
import sys

result = json.load(sys.stdin)
if result.get("UnprocessedItems"):
    raise SystemExit("ERROR: DynamoDB dejó elementos sin procesar.")
' <<< "$response"

echo "===> M07: verificando los cuatro documentos..."

result="$(aws dynamodb scan \
    --table-name "$TABLE" \
    --filter-expression 'begins_with(eventId, :prefix)' \
    --expression-attribute-values '{":prefix":{"S":"M07-LEGACY-"}}' \
    --select COUNT \
    --endpoint-url "$ENDPOINT" \
    --region "$AWS_DEFAULT_REGION")"

python3 -c '
import json
import sys

data = json.load(sys.stdin)
count = data.get("Count", 0)

if count != 4:
    raise SystemExit(
        f"ERROR: se esperaban 4 documentos M07, se encontraron {count}."
    )

print(f"PASS: {count} documentos heredados v1 verificados.")
' <<< "$result"

echo "===> M07: carga de fixtures completada."
