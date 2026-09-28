#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo " CDRL - Verificacion M04"
echo "========================================"

echo ""
echo "[1/4] Preparando prototipo NoSQL..."
bash scripts/nosql_setup.sh

echo ""
echo "[2/4] Cargando datos y consultas..."
bash scripts/nosql_queries.sh > /dev/null

echo "PASS - Datos de prueba preparados"

echo ""
echo "[3/4] Ejecutando pruebas M04..."
bash tests/test_m04.sh

echo ""
echo "[4/4] Generando artifact..."

mkdir -p artifacts

cat > artifacts/m04-nosql-evaluation.json <<EOF
{
  "assignmentId": "m04-nosql-architecture",
  "status": "passed",
  "database": {
    "engine": "DynamoDB Local",
    "table": "cdrl_telemetry_docs",
    "endpoint": "http://127.0.0.1:8000"
  },
  "tests": {
    "normalCase": "passed",
    "boundaryCase1": "passed",
    "boundaryCase2": "passed",
    "declaredFailure": "passed",
    "representativeQueries": "passed"
  }
}
EOF

echo "PASS - Artifact generado"

echo ""
echo "Artifact:"
echo "artifacts/m04-nosql-evaluation.json"

echo ""
echo "========================================"
echo " M04: VERIFICACION COMPLETADA"
echo "========================================"