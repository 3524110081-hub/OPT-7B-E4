#!/usr/bin/env bash

set -euo pipefail

echo "===> Ejecutando verificacion de M01..."

if [ ! -f "tests/test_m01.sh" ]; then
  echo "ERROR: No se encontró el archivo de verificación M01."
  exit 1
fi

bash tests/test_m01.sh

echo "===> Verificación de M01 completada."