#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/m06_common.sh"
m06_require

echo "========================================"
echo " M06 - Recuperacion desde respaldo"
echo "========================================"

backup="$(m06_get "$M06_BACKUP_TABLE" "$M06_OLD_ID")"
current="$(m06_get "$M06_EVENTS_TABLE" "$M06_OLD_ID")"

# Verificar respaldo y evitar sobrescribir documentos diferentes.
status="$(python3 - "$backup" "$current" "$M06_OLD_ID" <<'PY'
import json
import sys

backup = json.loads(sys.argv[1]).get("Item")
current = json.loads(sys.argv[2]).get("Item")
event_id = sys.argv[3]

if not backup or backup.get("eventId", {}).get("S") != event_id or backup.get("schemaVersion", {}).get("N") != "1":
    raise SystemExit("FAIL - Respaldo invalido o inexistente.")

if current and current != backup:
    raise SystemExit("FAIL - Existe un documento diferente. No se sobrescribira.")

print("already-present" if current else "restore-required")
PY
)"

if [[ "$status" == "restore-required" ]]; then

    echo "Restaurando documento..."

    start_ns="$(python3 -c 'import time; print(time.monotonic_ns())')"

    item="$(python3 - "$backup" <<'PY'
import json
import sys

print(json.dumps(
    json.loads(sys.argv[1])["Item"],
    separators=(",", ":")
))
PY
)"

    m06_ddb put-item \
        --table-name "$M06_EVENTS_TABLE" \
        --item "$item" \
        --condition-expression 'attribute_not_exists(eventId)' \
        > /dev/null

    after="$(m06_get "$M06_EVENTS_TABLE" "$M06_OLD_ID")"

    end_ns="$(python3 -c 'import time; print(time.monotonic_ns())')"

    duration_ms="$(python3 - "$start_ns" "$end_ns" <<'PY'
import sys

print(round(
    (int(sys.argv[2]) - int(sys.argv[1])) / 1000000,
    3
))
PY
)"

    performed=true

else
    echo "El documento ya coincide con el respaldo."
    after="$current"
    duration_ms=null
    performed=false
fi

mkdir -p "$M06_ROOT/evidence"

# Comparar contenido y generar evidencia.
python3 - "$backup" "$after" "$duration_ms" "$performed" "$M06_OLD_ID" "$M06_BACKUP_TABLE" "$M06_EVENTS_TABLE" <<'PY' > "$M06_ROOT/evidence/m06-recovery.json"
import datetime
import hashlib
import json
import sys

backup = json.loads(sys.argv[1]).get("Item")
restored = json.loads(sys.argv[2]).get("Item")

if not backup or backup != restored:
    raise SystemExit("FAIL - La restauracion no coincide con el respaldo.")

canonical = json.dumps(
    backup,
    sort_keys=True,
    separators=(",", ":")
).encode("utf-8")

digest = hashlib.sha256(canonical).hexdigest()

result = {
    "module": "M06",
    "status": "PASS",
    "fixtureId": sys.argv[5],
    "backupTable": sys.argv[6],
    "destinationTable": sys.argv[7],
    "recoveryPerformed": sys.argv[4] == "true",
    "recoveryDurationMs": None if sys.argv[3] == "null" else float(sys.argv[3]),
    "backupEqualsRestored": True,
    "documentSha256": digest,
    "verifiedAtUtc": datetime.datetime.now(
        datetime.timezone.utc
    ).isoformat(),
    "measurementScope": "restore and verification; excludes prior downtime"
}

print(json.dumps(result, indent=2))
PY

echo "PASS - Documento identico al respaldo."

if [[ "$performed" == true ]]; then
    echo "PASS - Restauracion completada en ${duration_ms} ms."
else
    echo "INFO - No fue necesario restaurar."
fi

echo "Evidencia: evidence/m06-recovery.json"
echo "===> Recuperacion completada."