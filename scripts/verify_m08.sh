#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export AWS_ACCESS_KEY_ID=dummy
export AWS_SECRET_ACCESS_KEY=dummy
export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""

mkdir -p artifacts

echo "======================================"
echo " M08: VERIFICACION INTEGRAL"
echo "======================================"

echo ""
echo "1. Ejecutando pruebas QA..."
bash tests/test_m08.sh

echo ""
echo "2. Ejecutando benchmark..."
bash scripts/m08_benchmark.sh

echo ""
echo "3. Generando evidencia JSON..."

python3 - <<'PY'
import json
from datetime import datetime, timezone

benchmark_path = "artifacts/m08-benchmark.json"
baseline_path = "artifacts/m08-baseline-scan.json"
output_path = "artifacts/m08-verify.json"

with open(benchmark_path, encoding="utf-8") as f:
    benchmark = json.load(f)

results = benchmark["results"]

for operation in ("scan", "query"):
    data = results[operation]
    if data["runs"] < 20:
        raise SystemExit(f"ERROR: mediciones insuficientes en {operation}")
    if data["count"] != 50:
        raise SystemExit(f"ERROR: cantidad inesperada en {operation}")

if not benchmark["comparison"]["same_returned_count"]:
    raise SystemExit("ERROR: Scan y Query devolvieron cantidades diferentes.")

qa = {
    "normal_query": "PASS",
    "limit_without_next_page": "PASS",
    "invalid_cursor": "PASS"
}

verification = {
    "activity": "M08",
    "verification": "QA, pagination and performance",
    "status": "PASS",
    "executed_at": datetime.now(timezone.utc).isoformat(),
    "qa_tests": qa,
    "benchmark": {
        "table": benchmark["table"],
        "filter_type": benchmark["filter_type"],
        "runs_per_operation": results["scan"]["runs"],
        "percentile_method": benchmark["percentile_method"],
        "scan": {
            "count": results["scan"]["count"],
            "scanned_count": results["scan"]["scanned_count"],
            "p50_ms": results["scan"]["p50_ms"],
            "p95_ms": results["scan"]["p95_ms"],
            "consumed_capacity": results["scan"]["consumed_capacity"]
        },
        "query": {
            "count": results["query"]["count"],
            "scanned_count": results["query"]["scanned_count"],
            "p50_ms": results["query"]["p50_ms"],
            "p95_ms": results["query"]["p95_ms"],
            "consumed_capacity": results["query"]["consumed_capacity"]
        },
        "same_returned_count": True
    }
}

try:
    with open(baseline_path, encoding="utf-8") as f:
        baseline = json.load(f)
    verification["baseline_full_scan"] = {
        "duration_ms": baseline["duration_ms"],
        "pages": baseline["pages"],
        "scanned_count": baseline["scanned_count"],
        "returned_count": baseline["returned_count"]
    }
except FileNotFoundError:
    verification["baseline_full_scan"] = None

with open(output_path, "w", encoding="utf-8") as f:
    json.dump(verification, f, indent=4, ensure_ascii=False)

print(f"PASS: evidencia generada en {output_path}")
PY

echo ""
echo "======================================"
echo " PASS: M08 VERIFICADA"
echo "======================================"
