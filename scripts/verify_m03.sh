#!/usr/bin/env bash

set -euo pipefail

echo "========================================"
echo " CDRL - Verificacion M03"
echo "========================================"

if [ ! -f "tests/test_m03.sh" ]; then
    echo "ERROR: no existe tests/test_m03.sh"
    exit 1
fi

echo ""
echo "==> Ejecutando pruebas M03..."

bash tests/test_m03.sh

mkdir -p artifacts

cat > artifacts/m03-verify.json <<EOF
{
  "assignmentId": "m03-relational-security",
  "status": "passed",
  "tests": {
    "readerSelect": {
      "status": "passed",
      "description": "role_reader puede realizar SELECT sobre devices"
    },
    "writerInsert": {
      "status": "passed",
      "description": "role_writer puede realizar INSERT sobre devices"
    },
    "operatorSelect": {
      "status": "passed",
      "description": "role_operator puede realizar SELECT sobre devices"
    },
    "readerInsertDenied": {
      "status": "passed",
      "description": "role_reader no puede realizar INSERT sobre devices"
    },
    "readerUpdateDenied": {
      "status": "passed",
      "description": "role_reader no puede realizar UPDATE sobre devices"
    },
    "writerAlterDenied": {
      "status": "passed",
      "description": "role_writer no puede realizar ALTER TABLE sobre devices"
    },
    "operatorTelemetryDenied": {
      "status": "passed",
      "description": "role_operator no puede consultar telemetry_events"
    },
    "secretsNotVersioned": {
      "status": "passed",
      "description": "El archivo .env no esta versionado en Git"
    },
    "migratorSchemaOperation": {
        "status": "passed",
        "description": "role_migrator puede crear y eliminar objetos del esquema"
    }
  }
}
EOF

echo ""
echo "==> Artifact generado:"
echo "artifacts/m03-verify.json"

echo ""
echo "========================================"
echo " M03: VERIFICACION COMPLETADA"
echo "========================================"