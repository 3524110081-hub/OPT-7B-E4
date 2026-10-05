#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_PAGER=""
ENDPOINT="http://127.0.0.1:8000"

echo "===> Configurando Infraestructura Document Store (M05)..."

# 1. Limpiar tabla previa
aws dynamodb delete-table \
    --table-name cdrl_events \
    --endpoint-url $ENDPOINT \
    --region us-east-1 > /dev/null 2>&1 || true

# 2. Crear tabla con Llave Primaria (eventId) e Índices Secundarios (GSI)
echo "===> Creando tabla cdrl_events con GSIs para las consultas del ADR..."
aws dynamodb create-table \
    --table-name cdrl_events \
    --attribute-definitions \
        AttributeName=eventId,AttributeType=S \
        AttributeName=type,AttributeType=S \
        AttributeName=source,AttributeType=S \
        AttributeName=timestamp,AttributeType=S \
    --key-schema \
        AttributeName=eventId,KeyType=HASH \
    --global-secondary-indexes \
        "IndexName=TypeTimestampIndex,KeySchema=[{AttributeName=type,KeyType=HASH},{AttributeName=timestamp,KeyType=RANGE}],Projection={ProjectionType=ALL}" \
        "IndexName=SourceTimestampIndex,KeySchema=[{AttributeName=source,KeyType=HASH},{AttributeName=timestamp,KeyType=RANGE}],Projection={ProjectionType=ALL}" \
    --billing-mode PAY_PER_REQUEST \
    --endpoint-url $ENDPOINT \
    --region us-east-1 > /dev/null

echo "===> Infraestructura e índices creados exitosamente."