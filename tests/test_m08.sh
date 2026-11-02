#!/usr/bin/env bash
set -euo pipefail

export AWS_ACCESS_KEY_ID=dummy
export AWS_SECRET_ACCESS_KEY=dummy
export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""

ENDPOINT="${DYNAMODB_ENDPOINT:-http://127.0.0.1:8000}"
TABLE="${DYNAMODB_TABLE:-cdrl_events}"

echo "===> M08 QA: iniciando pruebas..."

echo "1. Consulta normal..."
NORMAL=$(aws dynamodb query \
  --table-name "$TABLE" \
  --index-name TypeTimestampIndex \
  --key-condition-expression "#t = :type" \
  --expression-attribute-names '{"#t":"type"}' \
  --expression-attribute-values '{":type":{"S":"temperature"}}' \
  --select COUNT \
  --endpoint-url "$ENDPOINT")

COUNT=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["Count"])' <<< "$NORMAL")

if [[ "$COUNT" -ne 50 ]]; then
  echo "FAIL: se esperaban 50 documentos, encontrados: $COUNT"
  exit 1
fi
echo "PASS: consulta normal ($COUNT documentos)."

echo "2. Límite sin más páginas..."
LIMIT_RESULT=$(aws dynamodb query \
  --table-name "$TABLE" \
  --index-name TypeTimestampIndex \
  --key-condition-expression "#t = :type" \
  --expression-attribute-names '{"#t":"type"}' \
  --expression-attribute-values '{":type":{"S":"temperature"}}' \
  --limit 100 \
  --endpoint-url "$ENDPOINT")

python3 -c '
import json,sys
r=json.load(sys.stdin)
assert r["Count"] == 50, f"Count inesperado: {r['"'"'Count'"'"']}"
assert "LastEvaluatedKey" not in r, "Se esperaba que no hubiera más páginas"
' <<< "$LIMIT_RESULT"

echo "PASS: límite suficiente, no existe página siguiente."

echo "3. Cursor inválido..."
BAD_CURSOR='{"eventId":{"S":"cursor-inexistente"}}'

if aws dynamodb query \
  --table-name "$TABLE" \
  --index-name TypeTimestampIndex \
  --key-condition-expression "#t = :type" \
  --expression-attribute-names '{"#t":"type"}' \
  --expression-attribute-values '{":type":{"S":"temperature"}}' \
  --exclusive-start-key "$BAD_CURSOR" \
  --endpoint-url "$ENDPOINT" \
  >/tmp/m08-invalid-cursor.out 2>&1; then
  echo "FAIL: DynamoDB aceptó un cursor inválido."
  exit 1
fi

if ! grep -Eqi 'ValidationException|ExclusiveStartKey|Invalid' /tmp/m08-invalid-cursor.out; then
  cat /tmp/m08-invalid-cursor.out
  echo "FAIL: el error no corresponde a una validación de cursor."
  exit 1
fi

echo "PASS: cursor inválido rechazado por DynamoDB."
echo "===> PASS: las tres pruebas QA de M08 finalizaron correctamente."
