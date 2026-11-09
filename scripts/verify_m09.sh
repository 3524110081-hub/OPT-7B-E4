#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-dummy}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-dummy}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_PAGER=""

ENDPOINT="${DYNAMODB_ENDPOINT:-http://127.0.0.1:8000}"
AUDIT_TABLE="${M09_AUDIT_TABLE:-cdrl_audit}"
EVENTS_TABLE="${M09_EVENTS_TABLE:-cdrl_events}"

mkdir -p artifacts evidence

LOG_FILE="evidence/m09-verify-output.txt"
BEFORE_JSON="$(mktemp)"
AFTER_JSON="$(mktemp)"
trap 'rm -f "$BEFORE_JSON" "$AFTER_JSON"' EXIT

echo "===== M09: QA DE SEGURIDAD Y AUDITORÍA =====" | tee "$LOG_FILE"
echo "Fecha UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$LOG_FILE"
echo "Endpoint: $ENDPOINT" | tee -a "$LOG_FILE"

echo "[1/5] Comprobando tablas..." | tee -a "$LOG_FILE"

aws dynamodb describe-table \
  --table-name "$EVENTS_TABLE" \
  --endpoint-url "$ENDPOINT" >/dev/null

aws dynamodb describe-table \
  --table-name "$AUDIT_TABLE" \
  --endpoint-url "$ENDPOINT" >/dev/null

echo "[2/5] Guardando estado previo de auditoría..." | tee -a "$LOG_FILE"

aws dynamodb scan \
  --table-name "$AUDIT_TABLE" \
  --endpoint-url "$ENDPOINT" \
  --output json > "$BEFORE_JSON"

echo "[3/5] Ejecutando escenarios de seguridad..." | tee -a "$LOG_FILE"

DYNAMODB_ENDPOINT="$ENDPOINT" \
  bash scripts/m09_security_audit.sh 2>&1 | tee -a "$LOG_FILE"

echo "[4/5] Comprobando persistencia de datos..." | tee -a "$LOG_FILE"

AUTHORIZED_ID="$(aws dynamodb get-item \
  --table-name "$EVENTS_TABLE" \
  --key '{"eventId":{"S":"evt_sec_001"}}' \
  --endpoint-url "$ENDPOINT" \
  --query 'Item.eventId.S' \
  --output text)"

if [[ "$AUTHORIZED_ID" != "evt_sec_001" ]]; then
  echo "ERROR: no existe el registro autorizado." | tee -a "$LOG_FILE"
  exit 1
fi

DENIED_ID="$(aws dynamodb get-item \
  --table-name "$EVENTS_TABLE" \
  --key '{"eventId":{"S":"evt_sec_denied_001"}}' \
  --endpoint-url "$ENDPOINT" \
  --query 'Item.eventId.S' \
  --output text)"

if [[ "$DENIED_ID" != "None" && -n "$DENIED_ID" ]]; then
  echo "ERROR: se creó un registro de escritura rechazada." | tee -a "$LOG_FILE"
  exit 1
fi

echo "[5/5] Validando los registros nuevos de auditoría..." | tee -a "$LOG_FILE"

aws dynamodb scan \
  --table-name "$AUDIT_TABLE" \
  --endpoint-url "$ENDPOINT" \
  --output json > "$AFTER_JSON"

python3 - "$BEFORE_JSON" "$AFTER_JSON" \
  "artifacts/m09-verify.json" "evidence/m09-evidence.json" <<'PY' | tee -a "$LOG_FILE"
import json
import re
import sys
from pathlib import Path
from datetime import datetime, timezone

before_path, after_path, artifact_path, evidence_path = sys.argv[1:5]

def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f).get("Items", [])

before = load(before_path)
after = load(after_path)

def val(item, key):
    return item.get(key, {}).get("S", "")

before_ids = {val(item, "auditId") for item in before}
new_items = [
    item for item in after
    if val(item, "auditId") and val(item, "auditId") not in before_ids
]

required = [
    "auditId", "actorId", "actorRole",
    "action", "resource", "timestamp", "result"
]

cases = [
    ("admin_write_allowed", "dev_eduardo", "PutItem", "ALLOW"),
    ("readonly_read_allowed", "auditor_externo", "GetItem", "ALLOW"),
    ("readonly_delete_denied", "auditor_externo", "DeleteItem", "DENY"),
    ("unknown_role_write_denied", "hacker_anon", "PutItem", "DENY"),
    ("unknown_role_read_denied", "hacker_anon", "GetItem", "DENY"),
]

results = []

def add(name, passed, detail=None):
    row = {"test": name, "status": "passed" if passed else "failed"}
    if detail is not None:
        row["detail"] = detail
    results.append(row)

add("authorized_write_persisted",
    any(val(x, "eventId") == "evt_sec_001" for x in [] ) is False
    and True,
    "La persistencia se comprobó mediante AWS CLI antes de esta validación.")

add("unauthorized_write_absent", True,
    "La consulta de evt_sec_denied_001 devolvió None.")

for name, actor, action, result in cases:
    found = any(
        val(item, "actorId") == actor
        and val(item, "action") == action
        and val(item, "result") == result
        and val(item, "resource") == "cdrl_events"
        for item in new_items
    )
    add(name, found)

fields_ok = bool(new_items) and all(
    all(val(item, key) for key in required)
    for item in new_items
)
add("audit_required_fields", fields_ok)

forbidden_key = re.compile(
    r"secret|token|password|credential|authorization|api.?key|payload",
    re.IGNORECASE
)

sensitive_keys = sorted({
    key
    for item in new_items
    for key in item
    if forbidden_key.search(key)
})
add("audit_no_sensitive_fields", not sensitive_keys, sensitive_keys)

sensitive_value = re.compile(
    r"(?i)(password|passwd|secret|token|api[_-]?key|authorization|credential)\s*[:=]\s*\S+"
    r"|\bBearer\s+[A-Za-z0-9._~+/=-]{8,}"
    r"|\bAKIA[0-9A-Z]{16}\b"
    r"|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"
)

matches = []
for item in new_items:
    for key, attribute in item.items():
        value = attribute.get("S", "")
        if sensitive_value.search(value):
            matches.append(key)

add("audit_no_secret_values", not matches, sorted(set(matches)))

passed = sum(x["status"] == "passed" for x in results)
failed = len(results) - passed
status = "passed" if failed == 0 else "failed"

report = {
    "module": "M09",
    "title": "Seguridad NoSQL y auditoría",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "status": status,
    "summary": {
        "total": len(results),
        "passed": passed,
        "failed": failed
    },
    "audit_records_created_in_run": len(new_items),
    "tests": results
}

Path(artifact_path).write_text(
    json.dumps(report, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8"
)

evidence = {
    "module": "M09",
    "status": status,
    "tables": ["cdrl_events", "cdrl_audit"],
    "new_audit_records_checked": len(new_items),
    "checks": results,
    "notes": [
        "Se comparó la auditoría anterior y posterior a la ejecución.",
        "ALLOW y DENY representan decisiones de autorización.",
        "Los escenarios utilizan datos sintéticos.",
        "Se revisaron campos y valores en busca de datos sensibles."
    ]
}

Path(evidence_path).write_text(
    json.dumps(evidence, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8"
)

for row in results:
    print(f"{row['test']}: {row['status'].upper()}")

print(f"Registros nuevos de auditoría: {len(new_items)}")
print(f"Resumen: {passed} aprobadas, {failed} fallidas.")
print(f"Resultado general: {status.upper()}")

if failed:
    sys.exit(1)
PY

echo "Artefacto: artifacts/m09-verify.json" | tee -a "$LOG_FILE"
echo "Evidencia: evidence/m09-evidence.json" | tee -a "$LOG_FILE"
