#!/usr/bin/env bash
set -euo pipefail

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-dummy}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-dummy}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_PAGER=""

ENDPOINT="${DYNAMODB_ENDPOINT:-http://127.0.0.1:8000}"
REGION="us-east-1"
EVENTS="cdrl_events"
AUDIT="cdrl_audit"
BACKUP="cdrl_events_backup"

mkdir -p artifacts evidence
REPORT="artifacts/m06_result.txt"
: > "$REPORT"

log() {
    echo "$1" | tee -a "$REPORT"
}

awsd() {
    aws dynamodb "$@" --endpoint-url "$ENDPOINT" --region "$REGION"
}

audit() {
    local operation="$1"
    local resource="$2"
    local outcome="$3"
    local audit_id="m06-audit-$(date -u +%s)-$$-${RANDOM}"
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    awsd put-item \
        --table-name "$AUDIT" \
        --item "{
          \"auditId\":{\"S\":\"$audit_id\"},
          \"operation\":{\"S\":\"$operation\"},
          \"resourceId\":{\"S\":\"$resource\"},
          \"outcome\":{\"S\":\"$outcome\"},
          \"timestamp\":{\"S\":\"$timestamp\"},
          \"testRun\":{\"S\":\"M06\"}
        }" >/dev/null
}

get_event() {
    awsd get-item \
        --table-name "$EVENTS" \
        --key "{\"eventId\":{\"S\":\"$1\"}}" \
        --consistent-read \
        --query 'Item.eventId.S' \
        --output text
}

get_backup() {
    awsd get-item \
        --table-name "$BACKUP" \
        --key "{\"eventId\":{\"S\":\"$1\"}}" \
        --consistent-read \
        --query 'Item.eventId.S' \
        --output text
}

log "=== M06: Evolución de esquema y auditoría segura ==="
log "Endpoint: $ENDPOINT"
log "Fecha UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Verificar que las tablas ya existen. No crear ni borrar tablas aquí.
for table in "$EVENTS" "$AUDIT" "$BACKUP"; do
    if ! awsd describe-table --table-name "$table" >/dev/null 2>&1; then
        log "FAIL: No existe la tabla $table o DynamoDB no está disponible."
        log "Inicia el servicio y configura las tablas antes de repetir la prueba."
        exit 1
    fi
done

log "PASS: Las tablas de eventos, auditoría y respaldo existen."

# 1. Insertar un documento con esquema v1.
V1_ID="m06-v1-001"
V1='{
  "eventId":{"S":"m06-v1-001"},
  "type":{"S":"telemetry.temperature"},
  "source":{"S":"sensor-m06"},
  "timestamp":{"S":"2026-10-11T20:00:00Z"},
  "schemaVersion":{"N":"1"},
  "payload":{"S":"{\"temperature\":27.5}"}
}'

awsd put-item --table-name "$EVENTS" --item "$V1" >/dev/null
audit "INSERT" "$V1_ID" "SUCCESS"

# 2. Insertar un documento v2 con campos nuevos y payload estructurado.
V2_ID="m06-v2-001"
V2='{
  "eventId":{"S":"m06-v2-001"},
  "type":{"S":"telemetry.temperature"},
  "source":{"S":"sensor-m06"},
  "timestamp":{"S":"2026-10-11T20:05:00Z"},
  "schemaVersion":{"N":"2"},
  "payload":{"M":{
    "temperature":{"N":"28.1"},
    "unit":{"S":"C"}
  }},
  "metadata":{"M":{
    "quality":{"S":"validated"},
    "origin":{"S":"m06-test"}
  }}
}'

awsd put-item --table-name "$EVENTS" --item "$V2" >/dev/null
audit "INSERT" "$V2_ID" "SUCCESS"

# 3. Comprobar coexistencia y versión de ambos documentos.
V1_FOUND="$(get_event "$V1_ID")"
V2_FOUND="$(get_event "$V2_ID")"

if [[ "$V1_FOUND" != "$V1_ID" || "$V2_FOUND" != "$V2_ID" ]]; then
    audit "VERIFY_SCHEMA" "$V1_ID,$V2_ID" "FAILURE"
    log "FAIL: No se encontraron ambos documentos."
    exit 1
fi

V1_VERSION="$(awsd get-item --table-name "$EVENTS" \
    --key "{\"eventId\":{\"S\":\"$V1_ID\"}}" \
    --consistent-read --query 'Item.schemaVersion.N' --output text)"

V2_VERSION="$(awsd get-item --table-name "$EVENTS" \
    --key "{\"eventId\":{\"S\":\"$V2_ID\"}}" \
    --consistent-read --query 'Item.schemaVersion.N' --output text)"

if [[ "$V1_VERSION" != "1" || "$V2_VERSION" != "2" ]]; then
    log "FAIL: Las versiones recuperadas no son las esperadas."
    exit 1
fi

log "PASS: v1 y v2 coexisten y conservan sus versiones."
audit "VERIFY_SCHEMA" "$V1_ID,$V2_ID" "SUCCESS"

# 4. Preparar una falla controlada y guardar el evento en el respaldo.
FAIL_ID="m06-failure-001"
FAIL_DOC='{
  "eventId":{"S":"m06-failure-001"},
  "type":{"S":"telemetry.test"},
  "source":{"S":"sensor-m06"},
  "timestamp":{"S":"2026-10-11T20:10:00Z"},
  "schemaVersion":{"N":"2"},
  "payload":{"M":{"test":{"BOOL":true}}}
}'

awsd put-item --table-name "$EVENTS" --item "$FAIL_DOC" >/dev/null
awsd put-item --table-name "$BACKUP" --item "$FAIL_DOC" >/dev/null

if [[ "$(get_backup "$FAIL_ID")" != "$FAIL_ID" ]]; then
    log "FAIL: No se verificó el respaldo del evento de prueba."
    exit 1
fi

log "PASS: El evento de prueba está respaldado."

# 5. Simular el borrado accidental de un registro clave de prueba.
awsd delete-item \
    --table-name "$EVENTS" \
    --key "{\"eventId\":{\"S\":\"$FAIL_ID\"}}" \
    --condition-expression "attribute_exists(eventId)" >/dev/null

audit "DELETE" "$FAIL_ID" "SUCCESS"

# 6. Verificar la ausencia en la tabla viva y la presencia en backup.
LIVE_AFTER="$(get_event "$FAIL_ID")"
BACKUP_AFTER="$(get_backup "$FAIL_ID")"

if [[ "$LIVE_AFTER" != "None" && -n "$LIVE_AFTER" ]]; then
    log "FAIL: El evento sigue presente en la tabla principal."
    exit 1
fi

if [[ "$BACKUP_AFTER" != "$FAIL_ID" ]]; then
    log "FAIL: El evento no se encontró en el respaldo."
    exit 1
fi

log "PASS: Falla controlada verificada; evento ausente en la tabla principal."
log "PASS: El evento permanece en el respaldo."
AUDIT_COUNT="$(awsd scan --table-name "$AUDIT" --select COUNT --query 'Count' --output text)"
if [[ "$AUDIT_COUNT" -lt 3 ]]; then
    log "FAIL: No se encontraron suficientes registros de auditoría."
    exit 1
fi
log "PASS: Auditoría verificada; registros encontrados: $AUDIT_COUNT."
log "Resultado: PASS"
log "Evidencia de texto: $REPORT"
log "=== M06 completado correctamente ==="
