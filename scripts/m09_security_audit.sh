#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_PAGER=""

ENDPOINT="${DYNAMODB_ENDPOINT:-http://127.0.0.1:8000}"

echo "===> M09: Inicializando Capa de Seguridad y Auditoría NoSQL..."

log_audit() {
    local actor="$1"
    local role="$2"
    local action="$3"
    local resource="$4"
    local result="$5"
    local timestamp
    local audit_id

    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    audit_id="aud_$(date -u +%Y%m%dT%H%M%S%N)_$$_${RANDOM}"

    aws dynamodb put-item \
        --table-name cdrl_audit \
        --endpoint-url "$ENDPOINT" \
        --item "{\"auditId\":{\"S\":\"$audit_id\"},\"actorId\":{\"S\":\"$actor\"},\"actorRole\":{\"S\":\"$role\"},\"action\":{\"S\":\"$action\"},\"resource\":{\"S\":\"$resource\"},\"timestamp\":{\"S\":\"$timestamp\"},\"result\":{\"S\":\"$result\"}}" \
        > /dev/null
}

execute_secure_op() {
    local actor="$1"
    local role="$2"
    local action="$3"
    local resource="$4"
    local is_allowed="DENY"

    # Los cuatro primeros argumentos son metadatos.
    # Los restantes contienen el comando y sus argumentos.
    shift 4

    if [[ "$role" == "admin" ]]; then
        is_allowed="ALLOW"
    elif [[ "$role" == "readonly_user" ]]; then
        case "$action" in
            GetItem|Query|Scan)
                is_allowed="ALLOW"
                ;;
        esac
    fi

    # Registrar la decisión de autorización sin guardar el payload.
    log_audit "$actor" "$role" "$action" "$resource" "$is_allowed"

    if [[ "$is_allowed" == "ALLOW" ]]; then
        echo "  -> [ALLOW] Usuario '$actor' ($role): $action en $resource permitido."

        # Ejecutar los argumentos directamente, sin eval.
        if "$@" > /dev/null 2>&1; then
            return 0
        else
            echo "  -> [ERROR] La operación autorizada no pudo ejecutarse."
            return 2
        fi
    else
        echo "  -> [DENY] ALERTA: Usuario '$actor' ($role) intentó $action en $resource. OPERACIÓN RECHAZADA."
        return 1
    fi
}

echo "===> Ejecutando Pruebas de Seguridad (Simulación de Tráfico)..."

# 1. Administrador: escritura permitida.
execute_secure_op "dev_eduardo" "admin" "PutItem" "cdrl_events" \
    aws dynamodb put-item \
    --table-name cdrl_events \
    --endpoint-url "$ENDPOINT" \
    --item '{"eventId":{"S":"evt_sec_001"},"type":{"S":"security.test"}}' || true

# 2. Usuario de solo lectura: lectura permitida.
execute_secure_op "auditor_externo" "readonly_user" "GetItem" "cdrl_events" \
    aws dynamodb get-item \
    --table-name cdrl_events \
    --endpoint-url "$ENDPOINT" \
    --key '{"eventId":{"S":"evt_sec_001"}}' || true

# 3. Usuario de solo lectura: eliminación rechazada.
execute_secure_op "auditor_externo" "readonly_user" "DeleteItem" "cdrl_events" \
    aws dynamodb delete-item \
    --table-name cdrl_events \
    --endpoint-url "$ENDPOINT" \
    --key '{"eventId":{"S":"evt_sec_001"}}' || true

# 4. Rol desconocido: escritura rechazada.
execute_secure_op "hacker_anon" "unknown_role" "PutItem" "cdrl_events" \
    aws dynamodb put-item \
    --table-name cdrl_events \
    --endpoint-url "$ENDPOINT" \
    --item '{"eventId":{"S":"evt_sec_denied_001"},"type":{"S":"security.denied-test"}}' || true

# 5. Rol desconocido: lectura rechazada.
execute_secure_op "hacker_anon" "unknown_role" "GetItem" "cdrl_events" \
    aws dynamodb get-item \
    --table-name cdrl_events \
    --endpoint-url "$ENDPOINT" \
    --key '{"eventId":{"S":"evt_sec_001"}}' || true

echo "===> Verificando tabla de auditoría (cdrl_audit)..."

aws dynamodb scan \
    --table-name cdrl_audit \
    --endpoint-url "$ENDPOINT" \
    --query "Items[*].[actorId.S, action.S, result.S]" \
    --output text

echo "===> Tareas del Integrante 1 y 2 completadas."
