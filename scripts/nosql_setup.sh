#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="dummy"
export AWS_SECRET_ACCESS_KEY="dummy"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_PAGER=""
ENDPOINT="http://127.0.0.1:8000"

echo "===> Configurando prototipo Document Store (DynamoDB Local)..."

aws dynamodb delete-table \
    --table-name cdrl_telemetry_docs \
    --endpoint-url $ENDPOINT \
    --region us-east-1 > /dev/null 2>&1 || true

aws dynamodb create-table \
    --table-name cdrl_telemetry_docs \
    --attribute-definitions \
        AttributeName=device_id,AttributeType=S \
        AttributeName=observed_at,AttributeType=S \
    --key-schema \
        AttributeName=device_id,KeyType=HASH \
        AttributeName=observed_at,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --endpoint-url $ENDPOINT \
    --region us-east-1 > /dev/null

echo "===> Prototipo Document creado exitosamente."