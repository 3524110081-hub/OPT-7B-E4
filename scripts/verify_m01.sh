#!/usr/bin/env bash

set -euo pipefail

echo "===> Ejecutando verificacion de M01..."

if [ ! -f "tests/test_m01.sh" ]; then
  echo "ERROR: No se encontró el archivo de verificación M01."
  exit 1
fi

bash tests/test_m01.sh

mkdir -p artifacts

cat > artifacts/m01-verify.json <<EOF
{
  "assignmentId": "m01-data-contract",
  "status": "passed",
  "tests": {
    "normalCase": {
      "description": "cpu_usage = 50 desde el seed",
      "status": "passed"
    },
    "lowerBoundary": {
      "description": "cpu_usage = 0",
      "status": "passed"
    },
    "upperBoundary": {
      "description": "cpu_usage = 100",
      "status": "passed"
    },
    "declaredFailure": {
      "description": "cpu_usage = 101 rechazado por la base de datos",
      "status": "passed"
    }
  }
}
EOF

echo "==> Resultado generado en artifacts/m01-verify.json"

echo "===> Verificación de M01 completada."