#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export DYNAMODB_ENDPOINT="${DYNAMODB_ENDPOINT:-http://127.0.0.1:8000}"
export DYNAMODB_TABLE="${DYNAMODB_TABLE:-cdrl_events}"
export M08_BENCHMARK_TYPE="${M08_BENCHMARK_TYPE:-temperature}"
export M08_BENCHMARK_RUNS="${M08_BENCHMARK_RUNS:-30}"

mkdir -p artifacts

echo "===> M08: benchmark Scan vs Query..."
echo "Tabla: $DYNAMODB_TABLE"
echo "Tipo: $M08_BENCHMARK_TYPE"
echo "Mediciones por operación: $M08_BENCHMARK_RUNS"

python3 - <<'PY'
import os
import json
import math
import subprocess
import time
from datetime import datetime, timezone

endpoint = os.environ["DYNAMODB_ENDPOINT"]
table = os.environ["DYNAMODB_TABLE"]
event_type = os.environ["M08_BENCHMARK_TYPE"]
runs = int(os.environ["M08_BENCHMARK_RUNS"])
region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")

if runs < 20:
    raise SystemExit("ERROR: Se requieren al menos 20 mediciones.")

env = os.environ.copy()
env["AWS_ACCESS_KEY_ID"] = "dummy"
env["AWS_SECRET_ACCESS_KEY"] = "dummy"
env["AWS_DEFAULT_REGION"] = region
env["AWS_PAGER"] = ""
env["AWS_MAX_ATTEMPTS"] = "1"
env["AWS_EC2_METADATA_DISABLED"] = "true"

values = json.dumps({":type": {"S": event_type}})
names = json.dumps({"#t": "type"})

def execute(operation):
    args = [
        "aws", "dynamodb", operation,
        "--table-name", table,
        "--expression-attribute-names", names,
        "--expression-attribute-values", values,
        "--select", "COUNT",
        "--return-consumed-capacity", "TOTAL",
        "--endpoint-url", endpoint,
        "--region", region,
        "--output", "json"
    ]

    if operation == "scan":
        args += ["--filter-expression", "#t = :type"]
    else:
        args += [
            "--index-name", "TypeTimestampIndex",
            "--key-condition-expression", "#t = :type"
        ]

    start = time.perf_counter()
    result = subprocess.run(
        args, capture_output=True, text=True, env=env
    )
    elapsed = (time.perf_counter() - start) * 1000

    if result.returncode != 0:
        raise RuntimeError(
            f"Falló {operation}:\n{result.stderr}"
        )

    return elapsed, json.loads(result.stdout)

def nearest_rank(samples, percentile):
    ordered = sorted(samples)
    position = math.ceil(percentile * len(ordered))
    return round(ordered[position - 1], 3)

print("===> Ejecutando calentamiento...")
for operation in ("scan", "query"):
    for _ in range(3):
        execute(operation)

samples = {"scan": [], "query": []}
metrics = {}

print("===> Recopilando mediciones...")
for i in range(runs):
    order = ["scan", "query"] if i % 2 == 0 else ["query", "scan"]

    for operation in order:
        elapsed, result = execute(operation)
        samples[operation].append(round(elapsed, 3))

        current = {
            "count": result.get("Count", 0),
            "scanned_count": result.get("ScannedCount", 0),
            "consumed_capacity": result.get("ConsumedCapacity")
        }

        if operation not in metrics:
            metrics[operation] = current
        elif (
            metrics[operation]["count"] != current["count"]
            or metrics[operation]["scanned_count"] != current["scanned_count"]
        ):
            raise RuntimeError(
                f"Los resultados de {operation} cambiaron durante "
                "el benchmark. Revisa si hay escrituras concurrentes."
            )

scan_count = metrics["scan"]["count"]
query_count = metrics["query"]["count"]

if scan_count != query_count:
    raise SystemExit(
        f"ERROR: resultados distintos. Scan={scan_count}, "
        f"Query={query_count}"
    )

if scan_count != 50:
    raise SystemExit(
        f"ERROR: se esperaban 50 documentos de tipo {event_type}, "
        f"pero ambas operaciones encontraron {scan_count}. "
        "Revisa la carga de M08 antes de continuar."
    )

results = {}

for operation in ("scan", "query"):
    values_ms = samples[operation]
    results[operation] = {
        "samples_ms": values_ms,
        "runs": len(values_ms),
        "p50_ms": nearest_rank(values_ms, 0.50),
        "p95_ms": nearest_rank(values_ms, 0.95),
        "count": metrics[operation]["count"],
        "scanned_count": metrics[operation]["scanned_count"],
        "consumed_capacity": metrics[operation]["consumed_capacity"]
    }

scan_p50 = results["scan"]["p50_ms"]
query_p50 = results["query"]["p50_ms"]
scan_p95 = results["scan"]["p95_ms"]
query_p95 = results["query"]["p95_ms"]

artifact = {
    "benchmark": "M08 Scan vs Query",
    "table": table,
    "endpoint": endpoint,
    "filter_type": event_type,
    "executed_at": datetime.now(timezone.utc).isoformat(),
    "warmup_runs_per_operation": 3,
    "percentile_method": "nearest_rank",
    "percentile_formula": "rank = ceil(p * n); position is 1-based",
    "duration_unit": "milliseconds",
    "results": results,
    "comparison": {
        "same_returned_count": scan_count == query_count,
        "p50_scan_over_query_ratio": round(scan_p50 / query_p50, 3) if query_p50 else None,
        "p95_scan_over_query_ratio": round(scan_p95 / query_p95, 3) if query_p95 else None
    }
}

path = "artifacts/m08-benchmark.json"

with open(path, "w", encoding="utf-8") as file:
    json.dump(artifact, file, indent=4, ensure_ascii=False)

print("\n===> RESULTADOS DEL BENCHMARK")
for operation in ("scan", "query"):
    result = results[operation]
    print(f"\n{operation.upper()}")
    print(f"  Documentos encontrados: {result['count']}")
    print(f"  Documentos examinados: {result['scanned_count']}")
    print(f"  p50: {result['p50_ms']} ms")
    print(f"  p95: {result['p95_ms']} ms")

print(f"\nRatio p50 Scan/Query: {artifact['comparison']['p50_scan_over_query_ratio']}")
print(f"Ratio p95 Scan/Query: {artifact['comparison']['p95_scan_over_query_ratio']}")
print(f"\nArchivo generado: {path}")
print("PASS: benchmark completado.")
PY
