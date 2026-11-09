#!/bin/bash
set -e
export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_PAGER=""
ENDPOINT="http://127.0.0.1:8000"

echo "===> M09: Inicializando Capa de Seguridad y Auditoría NoSQL..."

# ---------------------------------------------------------
# INTEGRANTE 2: Sistema de Auditoría
# ---------------------------------------------------------
log_audit() {
    local actor=$1
    local role=$2
    local action=$3
    local resource=$4
    local result=$5
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    # Generar un ID único simple para la auditoría
    local audit_id="aud_$(date +%s%N | cut -b1-13)"

    # Se registra actor, acción, recurso y resultado. NO SE GUARDAN PAYLOADS NI SECRETOS.
    aws dynamodb put-item --table-name cdrl_audit --endpoint-url $ENDPOINT \
        --item '{"auditId": {"S": "'$audit_id'"}, "actorId": {"S": "'$actor'"}, "actorRole": {"S": "'$role'"}, "action": {"S": "'$action'"}, "resource": {"S": "'$resource'"}, "timestamp": {"S": "'$timestamp'"}, "result": {"S": "'$result'"}}' > /dev/null
}

# ---------------------------------------------------------
# INTEGRANTE 1: Control de Acceso (RBAC Middleware)
# ---------------------------------------------------------
execute_secure_op() {
    local actor=$1
    local role=$2
    local action=$3
    local resource=$4
    local dynamodb_command=$5

    local is_allowed="DENY"

    # MATRIZ DE PERMISOS (Control por operación)
    if [ "$role" == "admin" ]; then
        is_allowed="ALLOW" # El admin puede todo
    elif [ "$role" == "readonly_user" ]; then
        if [[ "$action" == "GetItem" || "$action" == "Query" || "$action" == "Scan" ]]; then
            is_allowed="ALLOW" # Solo lecturas
        fi
    fi
    # Cualquier otro rol o acción no contemplada queda en DENY por defecto.

    # Registrar en auditoría ANTES de ejecutar (Integrante 2)
    log_audit "$actor" "$role" "$action" "$resource" "$is_allowed"

    # Ejecución o Bloqueo (Integrante 1)
    if [ "$is_allowed" == "ALLOW" ]; then
        echo "  -> [ALLOW] Usuario '$actor' ($role): $action en $resource permitido."
        eval $dynamodb_command > /dev/null 2>&1
        return 0
    else
        echo "  -> [DENY] ALERTA: Usuario '$actor' ($role) intentó $action en $resource. OPERACIÓN RECHAZADA."
        return 1
    fi
}

echo "===> Ejecutando Pruebas de Seguridad (Simulación de Tráfico)..."

# Prueba 1: Admin insertando datos (Debe pasar)
CMD_PUT="aws dynamodb put-item --table-name cdrl_events --endpoint-url $ENDPOINT --item '{\"eventId\": {\"S\": \"evt_sec_001\"}, \"type\": {\"S\": \"security.test\"}}'"
execute_secure_op "dev_eduardo" "admin" "PutItem" "cdrl_events" "$CMD_PUT" || true

# Prueba 2: Usuario de solo lectura leyendo datos (Debe pasar)
CMD_GET="aws dynamodb get-item --table-name cdrl_events --endpoint-url $ENDPOINT --key '{\"eventId\": {\"S\": \"evt_sec_001\"}}'"
execute_secure_op "auditor_externo" "readonly_user" "GetItem" "cdrl_events" "$CMD_GET" || true

# Prueba 3: ABUSO - Usuario de solo lectura intentando borrar datos (Debe fallar y auditarse)
CMD_DEL="aws dynamodb delete-item --table-name cdrl_events --endpoint-url $ENDPOINT --key '{\"eventId\": {\"S\": \"evt_sec_001\"}}'"
execute_secure_op "auditor_externo" "readonly_user" "DeleteItem" "cdrl_events" "$CMD_DEL" || true

# Prueba 4: ABUSO - Actor desconocido intentando inyectar datos (Debe fallar y auditarse)
execute_secure_op "hacker_anon" "unknown_role" "PutItem" "cdrl_events" "$CMD_PUT" || true

echo "===> Verificando tabla de auditoría (cdrl_audit)..."
aws dynamodb scan --table-name cdrl_audit --endpoint-url $ENDPOINT --query "Items[*].[actorId.S, action.S, result.S]" --output text

echo "===> Tareas del Integrante 1 y 2 completadas."