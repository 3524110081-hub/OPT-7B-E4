-- M01: Datos sintéticos de telemetría
-- Seed reproducible para pruebas del contrato de datos.

INSERT INTO devices (
    id,
    device_uid,
    device_type
)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'device-m01-001',
    'sensor'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO telemetry_events (
    id,
    device_id,
    metric,
    value,
    unit,
    observed_at
)
VALUES (
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000001',
    'cpu_usage',
    50,
    '%',
    '2026-09-01T10:00:00Z'
)
ON CONFLICT (id) DO NOTHING;