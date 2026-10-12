#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/m06_common.sh"
m06_require

echo "========================================"
echo " M06 - Evolucion documental"
echo "========================================"

echo "Consultando documento v1..."

old="$(m06_get "$M06_EVENTS_TABLE" "$M06_OLD_ID")"

new_item="$(python3 -c '
import json
import sys

record = json.load(sys.stdin).get("Item")

if not record or record.get("schemaVersion", {}).get("N") != "1":
    raise SystemExit("ERROR: No se encontro un documento v1 valido")

original_payload = json.loads(record["payload"]["S"])

new_record = dict(record)

new_record["eventId"] = {"S": "evt_dr_002"}
new_record["schemaVersion"] = {"N": "2"}

new_record["payload"] = {
    "S": json.dumps(
        {**original_payload, "unit": "celsius"},
        separators=(",", ":")
    )
}

new_record["migrationFrom"] = {"S": "evt_dr_001"}
new_record["status"] = {"S": "new"}

print(json.dumps(new_record, separators=(",", ":")))
' <<< "$old")"

echo "Verificando si ya existe la version 2..."

existing="$(m06_get "$M06_EVENTS_TABLE" "$M06_NEW_ID")"

if python3 -c '
import json
import sys

x = json.load(sys.stdin).get("Item", {})

if not x:
    sys.exit(1)

if x.get("schemaVersion", {}).get("N") != "2":
    raise SystemExit("ERROR: Version incompatible")

if x.get("migrationFrom", {}).get("S") != "evt_dr_001":
    raise SystemExit("ERROR: Origen de migracion incorrecto")

if x.get("status", {}).get("S") not in ("new", "reviewed"):
    raise SystemExit("ERROR: Estado incompatible")

sys.exit(0)
' <<< "$existing"; then

    echo "PASS - Documento v2 ya existe."

else

    if python3 -c '
import json
import sys

record = json.load(sys.stdin).get("Item")
sys.exit(0 if not record else 1)
' <<< "$existing"; then

        m06_ddb put-item \
            --table-name "$M06_EVENTS_TABLE" \
            --item "$new_item" \
            --condition-expression "attribute_not_exists(eventId)" \
            > /dev/null

        echo "PASS - Documento v2 creado correctamente."

    else
        echo "FAIL - Ya existe un documento incompatible."
        exit 1
    fi
fi

echo "===> Evolucion documental completada."