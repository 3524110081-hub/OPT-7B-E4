#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/m06_common.sh"
m06_require

# La prueba destructiva solo se permite contra DynamoDB Local.
case "${M06_ENDPOINT%/}" in
    http://127.0.0.1:8000|http://localhost:8000) ;;
    *)
        echo "FAIL - La falla controlada solo se permite en DynamoDB Local." >&2
        exit 1
        ;;
esac

if [[ "$M06_OLD_ID" != "evt_dr_001" ]]; then
    echo "FAIL - Identificador del fixture no permitido." >&2
    exit 1
fi

echo "========================================"
echo " M06 - Simulacion de falla controlada"
echo "========================================"

live="$(m06_get "$M06_EVENTS_TABLE" "$M06_OLD_ID")"
backup="$(m06_get "$M06_BACKUP_TABLE" "$M06_OLD_ID")"

# Verificar el respaldo antes de eliminar.
python3 - "$live" "$backup" "$M06_OLD_ID" <<'PY'
import json
import sys

live = json.loads(sys.argv[1]).get("Item")
backup = json.loads(sys.argv[2]).get("Item")
event_id = sys.argv[3]

if not backup or backup.get("eventId", {}).get("S") != event_id or backup.get("schemaVersion", {}).get("N") != "1":
    raise SystemExit("FAIL - Respaldo v1 inexistente o invalido. No se eliminara nada.")

if not live:
    raise SystemExit("FAIL - El documento original no existe.")

if live != backup:
    raise SystemExit("FAIL - Documento original diferente al respaldo. No se eliminara nada.")

print("PASS - Respaldo verificado correctamente.")
PY

echo "Eliminando unicamente el fixture sintetico..."

m06_ddb delete-item \
    --table-name "$M06_EVENTS_TABLE" \
    --key "{\"eventId\":{\"S\":\"$M06_OLD_ID\"}}" \
    --condition-expression 'attribute_exists(eventId) AND schemaVersion = :version' \
    --expression-attribute-values '{":version":{"N":"1"}}' \
    > /dev/null

after="$(m06_get "$M06_EVENTS_TABLE" "$M06_OLD_ID")"

python3 - "$after" <<'PY'
import json
import sys

record = json.loads(sys.argv[1]).get("Item")

if record:
    raise SystemExit("FAIL - El documento todavia existe.")

print("PASS - Falla controlada comprobada.")
PY

echo "El respaldo permanece disponible."
echo "===> Simulacion completada."