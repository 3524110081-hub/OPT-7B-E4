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
OUTPUT="artifacts/m08-baseline-scan.json"

mkdir -p artifacts

echo "===> M08: ejecutando Scan completo sobre $TABLE..."

python3 - "$ENDPOINT" "$TABLE" "$AWS_DEFAULT_REGION" "$OUTPUT" <<'PY'
import json
import subprocess
import sys
import time
from datetime import datetime, timezone

endpoint, table, region, output = sys.argv[1:]

start = time.perf_counter()
exclusive_start_key = None
total_scanned = 0
total_returned = 0
pages = 0

while True:
    command = [
        "aws", "dynamodb", "scan",
        "--table-name", table,
        "--endpoint-url", endpoint,
        "--region", region,
        "--no-paginate",
        "--output", "json"
    ]

    if exclusive_start_key:
        command.extend([
            "--exclusive-start-key",
            json.dumps(exclusive_start_key)
        ])

    response = subprocess.run(
        command,
        capture_output=True,
        text=True
    )

    if response.returncode != 0:
        print(response.stderr, file=sys.stderr)
        raise SystemExit("ERROR: falló el Scan de DynamoDB.")

    data = json.loads(response.stdout)

    pages += 1
    total_scanned += data.get("ScannedCount", 0)
    total_returned += data.get("Count", 0)

    exclusive_start_key = data.get("LastEvaluatedKey")

    if not exclusive_start_key:
        break

elapsed_ms = round((time.perf_counter() - start) * 1000, 3)

result = {
    "benchmark": "M08 baseline full scan",
    "table": table,
    "scan_type": "full_scan_without_filter",
    "executed_at": datetime.now(timezone.utc).isoformat(),
    "duration_ms": elapsed_ms,
    "pages": pages,
    "scanned_count": total_scanned,
    "returned_count": total_returned
}

with open(output, "w", encoding="utf-8") as file:
    json.dump(result, file, indent=2)

print(f"Tiempo total: {elapsed_ms} ms")
print(f"Paginas recorridas: {pages}")
print(f"Documentos examinados: {total_scanned}")
print(f"Documentos devueltos: {total_returned}")
print(f"Resultado guardado en: {output}")
PY

echo "===> M08: línea base completada."
