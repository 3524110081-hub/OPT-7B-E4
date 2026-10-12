#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../scripts/m06_common.sh"
m06_require

echo "========================================"
echo " M06 - Pruebas automatizadas"
echo "========================================"

# ========================================
# PRUEBA 1: CASO NORMAL
# ========================================

echo ""
echo "[1/5] Caso normal: Documento v2"

v2="$(m06_get "$M06_EVENTS_TABLE" "$M06_NEW_ID")"

python3 - "$v2" <<'PY'
import json
import sys

item = json.loads(sys.argv[1]).get("Item", {})

assert item.get("eventId", {}).get("S") == "evt_dr_002"
assert item.get("schemaVersion", {}).get("N") == "2"
assert item.get("migrationFrom", {}).get("S") == "evt_dr_001"
assert item.get("status", {}).get("S") == "reviewed"

payload = json.loads(item["payload"]["S"])

assert payload["temperature"] == 27.5
assert payload["unit"] == "celsius"

print("PASS - Documento v2 valido y consultable")
PY

# ========================================
# PRUEBA 2: LIMITE 1
# ========================================

echo ""
echo "[2/5] Caso limite 1: Compatibilidad v1"

v1="$(m06_get "$M06_EVENTS_TABLE" "$M06_OLD_ID")"
backup="$(m06_get "$M06_BACKUP_TABLE" "$M06_OLD_ID")"

python3 - "$v1" "$backup" <<'PY'
import json
import sys

v1 = json.loads(sys.argv[1]).get("Item", {})
backup = json.loads(sys.argv[2]).get("Item", {})

assert v1.get("schemaVersion", {}).get("N") == "1"
assert v1.get("eventId", {}).get("S") == "evt_dr_001"
assert v1 == backup

print("PASS - Documento v1 conservado y compatible")
print("PASS - Respaldo intacto")
PY

# ========================================
# PRUEBA 3: LIMITE 2
# ========================================

echo ""
echo "[3/5] Caso limite 2: Auditoria"

audit="$(m06_audit_get)"

python3 - "$audit" <<'PY'
import json
import sys

item = json.loads(sys.argv[1]).get("Item", {})

assert item.get("auditId", {}).get("S") == \
    "audit_evt_dr_002_status_v2"

assert item.get("eventId", {}).get("S") == "evt_dr_002"
assert item.get("action", {}).get("S") == "UPDATE"
assert item.get("before", {}).get("S") == "new"
assert item.get("after", {}).get("S") == "reviewed"
assert item.get("timestamp", {}).get("S")

# Revisar que no existan campos de secretos
for field in item:
    name = field.lower()

    for forbidden in [
        "password",
        "secret",
        "token",
        "credential",
        "connectionstring"
    ]:
        assert forbidden not in name

print("PASS - Auditoria registrada correctamente")
print("PASS - Sin campos de credenciales o secretos")
PY

# ========================================
# PRUEBA 4: FALLO DECLARADO
# ========================================

echo ""
echo "[4/5] Fallo declarado: Recuperacion"

recovery_file="$M06_ROOT/evidence/m06-recovery.json"

if [[ ! -f "$recovery_file" ]]; then
    echo "FAIL - No existe evidencia de recuperacion"
    exit 1
fi

python3 - "$recovery_file" "$backup" "$v1" <<'PY'
import hashlib
import json
import sys

with open(sys.argv[1], encoding="utf-8") as file:
    evidence = json.load(file)

backup = json.loads(sys.argv[2]).get("Item")
restored = json.loads(sys.argv[3]).get("Item")

assert evidence["status"] == "PASS"
assert evidence["recoveryPerformed"] is True
assert evidence["backupEqualsRestored"] is True
assert evidence["recoveryDurationMs"] >= 0
assert backup == restored

canonical = json.dumps(
    backup,
    sort_keys=True,
    separators=(",", ":")
).encode("utf-8")

digest = hashlib.sha256(canonical).hexdigest()

assert evidence["documentSha256"] == digest

print("PASS - Documento recuperado correctamente")
print("PASS - Integridad SHA-256 comprobada")
print(
    "Tiempo de recuperacion:",
    evidence["recoveryDurationMs"],
    "ms"
)
PY

# ========================================
# PRUEBA 5: CONSULTAS INDEXADAS
# ========================================

echo ""
echo "[5/5] Consultas usando indices"

for specification in \
    "TypeTimestampIndex|type|telemetry.temperature" \
    "SourceTimestampIndex|source|sensor-dr"
do
    IFS='|' read -r index field value <<< "$specification"

    result="$(m06_ddb query \
        --table-name "$M06_EVENTS_TABLE" \
        --index-name "$index" \
        --key-condition-expression \
        "#pk = :pk AND #ts >= :start" \
        --expression-attribute-names \
        "{\"#pk\":\"$field\",\"#ts\":\"timestamp\"}" \
        --expression-attribute-values \
        "{\":pk\":{\"S\":\"$value\"},\":start\":{\"S\":\"2026-01-01T00:00:00Z\"}}" \
        --output json)"

    python3 - "$result" "$M06_NEW_ID" "$index" <<'PY'
import json
import sys

response = json.loads(sys.argv[1])
event_id = sys.argv[2]
index = sys.argv[3]

items = response.get("Items", [])

assert any(
    item.get("eventId", {}).get("S") == event_id
    for item in items
), f"No se encontro {event_id} usando {index}"

print(f"PASS - Consulta correcta usando {index}")
PY

done

echo ""
echo "========================================"
echo " M06: TODAS LAS PRUEBAS PASARON"
echo "========================================"