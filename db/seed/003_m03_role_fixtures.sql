-- Fixture M03: operaciones DML con el rol role_writer
-- Integrante 2 - Consultas, Variables de Entorno y Rotación

BEGIN;

-- Cambiar temporalmente al rol con permisos de escritura
SET LOCAL ROLE role_writer;

-- Registro sintético para demostrar INSERT autorizado
INSERT INTO devices (
    id,
    device_uid,
    device_type
)
VALUES (
    '77777777-7777-7777-7777-777777777701',
    'm03-writer-device',
    'SENSOR-M03'
)
ON CONFLICT (id) DO NOTHING;

-- Registro sintético de telemetría
INSERT INTO telemetry_events (
    id,
    device_id,
    metric,
    unit,
    value,
    observed_at
)
VALUES (
    '88888888-8888-8888-8888-888888888801',
    '77777777-7777-7777-7777-777777777701',
    'temperature',
    'celsius',
    24.5,
    NOW()
)
ON CONFLICT (id) DO NOTHING;

COMMIT;