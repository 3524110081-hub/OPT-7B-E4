#!/usr/bin/env bash

set -euo pipefail

echo "========================================"
echo " CDRL - Verificacion M02"
echo "========================================"

if [ ! -f "tests/test_m02.sh" ]; then
    echo "ERROR: no existe tests/test_m02.sh"
    exit 1
fi

echo ""
echo "==> Ejecutando pruebas M02..."

bash tests/test_m02.sh

mkdir -p artifacts

cat > artifacts/m02-verify.json <<EOF
{
  "assignmentId": "m02-relational-model",
  "status": "passed",
  "tests": {
    "normalCase": {
      "status": "passed",
      "description": "Dispositivo con telemetria valida"
    },
    "emptyCase": {
      "status": "passed",
      "description": "Dispositivo valido sin eventos de telemetria"
    },
    "boundaryCase": {
      "status": "passed",
      "description": "Cadenas no vacias de longitud minima"
    },
    "parameterizedQuery": {
      "status": "passed",
      "description": "Consulta mediante PREPARE y EXECUTE"
    },
    "declaredFailure": {
      "status": "passed",
      "description": "device_uid vacio rechazado por PostgreSQL"
    }
  }
}
EOF

echo ""
echo "==> Artifact generado: artifacts/m02-verify.json"
echo "==> Verificacion M02 completada correctamente."