#!/usr/bin/env bash

# Configuracion compartida para M06
# Se utilizan exclusivamente datos sinteticos.

M06_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

M06_ENDPOINT="${DYNAMODB_ENDPOINT-http://127.0.0.1:8000}"
M06_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

M06_EVENTS_TABLE="${M06_EVENTS_TABLE:-cdrl_events}"
M06_BACKUP_TABLE="${M06_BACKUP_TABLE:-cdrl_events_backup}"
M06_AUDIT_TABLE="${M06_AUDIT_TABLE:-cdrl_audit}"

M06_OLD_ID="evt_dr_001"
M06_NEW_ID="evt_dr_002"
M06_AUDIT_ID="audit_evt_dr_002_status_v2"

export AWS_DEFAULT_REGION="$M06_REGION"
export AWS_PAGER=""

# Credenciales ficticias exclusivamente para DynamoDB Local.
if [[ "$M06_ENDPOINT" == "http://127.0.0.1:8000" ||
      "$M06_ENDPOINT" == "http://localhost:8000" ]]; then
    export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-dummy}"
    export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-dummy}"
fi

M06_AWS_ARGS=(--region "$M06_REGION")

if [[ -n "$M06_ENDPOINT" ]]; then
    M06_AWS_ARGS+=(--endpoint-url "$M06_ENDPOINT")
fi

# Ejecutar comandos DynamoDB
m06_ddb() {
    aws dynamodb "$@" "${M06_AWS_ARGS[@]}"
}

# Obtener documento por eventId
m06_get() {
    local table="$1"
    local id="$2"
    local result

    result="$(m06_ddb get-item \
        --table-name "$table" \
        --key "{\"eventId\":{\"S\":\"$id\"}}" \
        --consistent-read \
        --output json)" || return 1

    # Normalizar respuestas vacias de DynamoDB
    if [[ -z "${result//[[:space:]]/}" || "$result" == "null" ]]; then
        printf '{}\n'
    else
        printf '%s\n' "$result"
    fi
}

# Obtener registro de auditoria
m06_audit_get() {
    local result

    result="$(m06_ddb get-item \
        --table-name "$M06_AUDIT_TABLE" \
        --key "{\"auditId\":{\"S\":\"$M06_AUDIT_ID\"}}" \
        --consistent-read \
        --output json)" || return 1

    # Normalizar respuestas vacias de DynamoDB
    if [[ -z "${result//[[:space:]]/}" || "$result" == "null" ]]; then
        printf '{}\n'
    else
        printf '%s\n' "$result"
    fi
}

# Comprobar herramientas necesarias
m06_require() {
    local cmd

    for cmd in aws python3 date; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "ERROR: Falta instalar $cmd" >&2
            return 1
        fi
    done
}