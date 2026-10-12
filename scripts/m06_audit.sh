#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/m06_common.sh"
m06_require

echo "========================================"
echo " M06 - Auditoria de operaciones"
echo "========================================"

current="$(m06_get "$M06_EVENTS_TABLE" "$M06_NEW_ID")"
audit="$(m06_audit_get)"

state="$(python3 -c '
import json
import sys

record = json.load(sys.stdin).get("Item", {})
print(record.get("status", {}).get("S", "missing"))
' <<< "$current")"

audit_exists="$(python3 -c '
import json
import sys

record = json.load(sys.stdin).get("Item")
print("yes" if record else "no")
' <<< "$audit")"

if [[ "$state" == "reviewed" &&
      "$audit_exists" == "yes" ]]; then
    echo "PASS - Cambio ya auditado."
    exit 0
fi

if [[ "$state" != "new" ||
      "$audit_exists" != "no" ]]; then
    echo "FAIL - Estado inconsistente para auditar."
    exit 1
fi

changed_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

cat > "$tmp" <<JSON
[
  {
    "Update": {
      "TableName": "$M06_EVENTS_TABLE",
      "Key": {
        "eventId": {"S": "$M06_NEW_ID"}
      },
      "UpdateExpression": "SET #status = :new",
      "ConditionExpression": "attribute_exists(eventId) AND #status = :old AND #version = :v2",
      "ExpressionAttributeNames": {
        "#status": "status",
        "#version": "schemaVersion"
      },
      "ExpressionAttributeValues": {
        ":old": {"S": "new"},
        ":new": {"S": "reviewed"},
        ":v2": {"N": "2"}
      }
    }
  },
  {
    "Put": {
      "TableName": "$M06_AUDIT_TABLE",
      "Item": {
        "auditId": {"S": "$M06_AUDIT_ID"},
        "eventId": {"S": "$M06_NEW_ID"},
        "action": {"S": "UPDATE"},
        "actor": {"S": "m06-synthetic-qa"},
        "changedField": {"S": "status"},
        "before": {"S": "new"},
        "after": {"S": "reviewed"},
        "timestamp": {"S": "$changed_at"}
      },
      "ConditionExpression": "attribute_not_exists(auditId)"
    }
  }
]
JSON

echo "Registrando modificacion y auditoria..."

m06_ddb transact-write-items \
    --transact-items "file://$tmp" > /dev/null

echo "PASS - Modificacion registrada correctamente."
echo "PASS - Auditoria generada."
echo "===> Auditoria completada."