#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

source scripts/m06_common.sh
m06_require

mkdir -p artifacts evidence

ARTIFACT="artifacts/m06-verify.json"
EVIDENCE="evidence/m06-evidence.json"
RECOVERY="evidence/m06-recovery.json"
LOG="evidence/m06-verify-output.txt"

# Evitar presentar resultados anteriores como actuales.
rm -f "$ARTIFACT" "$EVIDENCE" "$RECOVERY"
: > "$LOG"

log() {
    echo "$1" | tee -a "$LOG"
}

run_step() {
    local title="$1"
    local script="$2"

    log ""
    log "$title"

    bash "$script" 2>&1 | tee -a "$LOG"
}

log "========================================"
log " CDRL - Verificacion Semana 6"
log "========================================"

log ""
log "[0/6] Comprobando infraestructura..."

for table in \
    "$M06_EVENTS_TABLE" \
    "$M06_BACKUP_TABLE" \
    "$M06_AUDIT_TABLE"
do
    if m06_ddb describe-table \
        --table-name "$table" \
        > /dev/null; then

        log "PASS - Tabla $table disponible"
    else
        log "FAIL - No se encontro la tabla $table"
        exit 1
    fi
done

run_step \
    "[1/6] Evolucion documental..." \
    "scripts/m06_evolution.sh"

run_step \
    "[2/6] Auditoria de operaciones..." \
    "scripts/m06_audit.sh"

run_step \
    "[3/6] Simulacion de falla..." \
    "scripts/m06_failure.sh"

run_step \
    "[4/6] Recuperacion desde respaldo..." \
    "scripts/m06_recovery.sh"

run_step \
    "[5/6] Ejecutando pruebas M06..." \
    "tests/test_m06.sh"

log ""
log "[6/6] Generando artifacts y evidence..."

python3 - "$RECOVERY" "$ARTIFACT" "$EVIDENCE" <<'PY'
import datetime
import json
import sys

recovery_path = sys.argv[1]
artifact_path = sys.argv[2]
evidence_path = sys.argv[3]

with open(recovery_path, encoding="utf-8") as file:
    recovery = json.load(file)

if (
    recovery.get("status") != "PASS"
    or recovery.get("recoveryPerformed") is not True
    or recovery.get("backupEqualsRestored") is not True
    or not isinstance(
        recovery.get("recoveryDurationMs"),
        (int, float)
    )
):
    raise SystemExit(
        "FAIL - Evidencia de recuperacion invalida"
    )

timestamp = datetime.datetime.now(
    datetime.timezone.utc
).isoformat()

artifact = {
    "module": "M06",
    "status": "PASS",
    "tests_executed": 5,
    "tests_passed": 5,
    "tests": {
        "normalCase": "PASS",
        "boundaryCase1": "PASS",
        "boundaryCase2": "PASS",
        "declaredFailure": "PASS",
        "indexedQueries": "PASS"
    },
    "recoveryDurationMs": recovery["recoveryDurationMs"],
    "verifiedAtUtc": timestamp
}

evidence = {
    "module": "M06",
    "status": "PASS",
    "fixtureId": recovery["fixtureId"],
    "documentEvolution": "PASS",
    "backwardCompatibility": "PASS",
    "auditVerification": "PASS",
    "failureSimulation": "PASS",
    "recoveryVerification": "PASS",
    "backupEqualsRestored": recovery["backupEqualsRestored"],
    "recoveryPerformed": recovery["recoveryPerformed"],
    "recoveryDurationMs": recovery["recoveryDurationMs"],
    "documentSha256": recovery["documentSha256"],
    "verifiedAtUtc": timestamp,
    "verificationLog": "evidence/m06-verify-output.txt",
    "recoveryEvidence": "evidence/m06-recovery.json"
}

with open(artifact_path, "w", encoding="utf-8") as file:
    json.dump(artifact, file, indent=2)
    file.write("\n")

with open(evidence_path, "w", encoding="utf-8") as file:
    json.dump(evidence, file, indent=2)
    file.write("\n")

print("PASS - Artifact generado")
print("PASS - Evidencia generada")
PY

log ""
log "========================================"
log " M06: VERIFICACION COMPLETADA"
log "========================================"

log ""
log "Archivos generados:"
log "$ARTIFACT"
log "$EVIDENCE"
log "$RECOVERY"
log "$LOG"