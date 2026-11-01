#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-dummy}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-dummy}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_PAGER=""

ENDPOINT="${DYNAMODB_ENDPOINT:-http://127.0.0.1:8000}"
TABLE="${DYNAMODB_TABLE:-cdrl_events}"
TOTAL=150
BATCH_SIZE=25
TMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TMP_DIR"' EXIT

echo "===> M08: generando $TOTAL documentos sintéticos..."

python3 - "$TMP_DIR" "$TOTAL" <<'PY'
import json
import os
import sys
from datetime import datetime, timedelta, timezone

output_dir = sys.argv[1]
total = int(sys.argv[2])

types = [
    ("temperature", "celsius"),
    ("humidity", "percent"),
    ("pressure", "kPa"),
]

start = datetime(2026, 10, 1, tzinfo=timezone.utc)

items = []

for i in range(1, total + 1):
    metric, unit = types[(i - 1) % len(types)]
    sensor_number = ((i - 1) % 10) + 1
    timestamp = start + timedelta(minutes=5 * i)

    if metric == "temperature":
        value = 20 + (i % 150) / 10
    elif metric == "humidity":
        value = 40 + (i % 500) / 10
    else:
        value = 100 + (i % 100) / 10

    item = {
        "eventId": {"S": f"M08-BASELINE-{i:04d}"},
        "type": {"S": metric},
        "source": {"S": f"sensor-M08-{sensor_number:02d}"},
        "timestamp": {"S": timestamp.isoformat().replace("+00:00", "Z")},
        "value": {"N": f"{value:.1f}"},
        "unit": {"S": unit},
    }

    items.append({"PutRequest": {"Item": item}})

batch_size = 25

for batch_number, start_index in enumerate(range(0, total, batch_size), start=1):
    batch = items[start_index:start_index + batch_size]
    path = os.path.join(output_dir, f"batch-{batch_number}.json")

    with open(path, "w", encoding="utf-8") as file:
        json.dump({"cdrl_events": batch}, file, indent=2)

print(f"Generados {len(items)} documentos en {((total - 1) // 25) + 1} lotes.")
PY

echo "===> M08: comprobando que existe la tabla $TABLE..."

aws dynamodb describe-table \
    --table-name "$TABLE" \
    --endpoint-url "$ENDPOINT" \
    --region "$AWS_DEFAULT_REGION" >/dev/null

echo "===> M08: insertando documentos por lotes..."

for batch_file in "$TMP_DIR"/batch-*.json; do
    echo "Procesando $(basename "$batch_file")..."

    request_file="$batch_file"
    attempt=1
    max_attempts=5

    while true; do
        response="$(aws dynamodb batch-write-item \
            --request-items "file://$request_file" \
            --endpoint-url "$ENDPOINT" \
            --region "$AWS_DEFAULT_REGION")"

        unprocessed="$(python3 -c '
import json
import sys

data = json.load(sys.stdin)
print(json.dumps(data.get("UnprocessedItems", {})))
' <<< "$response")"

        remaining="$(python3 -c '
import json
import sys

data = json.loads(sys.argv[1])
print(len(data.get("cdrl_events", [])))
' "$unprocessed")"

        if [ "$remaining" -eq 0 ]; then
            break
        fi

        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "ERROR: quedaron documentos sin procesar después de $max_attempts intentos."
            exit 1
        fi

        echo "Reintentando $remaining documentos..."
        printf '%s\n' "$unprocessed" > "$TMP_DIR/retry.json"
        request_file="$TMP_DIR/retry.json"
        attempt=$((attempt + 1))
        sleep 1
    done
done

echo "===> M08: verificando los documentos..."

result="$(aws dynamodb scan \
    --table-name "$TABLE" \
    --filter-expression 'begins_with(eventId, :prefix)' \
    --expression-attribute-values '{":prefix":{"S":"M08-BASELINE-"}}' \
    --select COUNT \
    --endpoint-url "$ENDPOINT" \
    --region "$AWS_DEFAULT_REGION")"

python3 -c '
import json
import sys

data = json.loads(sys.argv[1])
count = data.get("Count", 0)

if count != 150:
    raise SystemExit(f"ERROR: se esperaban 150 documentos M08 y se encontraron {count}.")

print(f"PASS: {count} documentos M08 verificados.")
' "$result"

echo "===> M08: seed masivo completado."
