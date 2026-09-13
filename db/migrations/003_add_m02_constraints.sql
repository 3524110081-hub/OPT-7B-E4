-- M02: Refuerzo de restricciones del modelo relacional
-- Integrante 1: Arquitectura y Restricciones de Base de Datos

DO $$
BEGIN
    -- devices.device_uid no debe aceptar cadenas vacías
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'devices_device_uid_not_empty'
    ) THEN
        ALTER TABLE devices
        ADD CONSTRAINT devices_device_uid_not_empty
        CHECK (device_uid <> '');
    END IF;

    -- devices.device_type no debe aceptar cadenas vacías
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'devices_device_type_not_empty'
    ) THEN
        ALTER TABLE devices
        ADD CONSTRAINT devices_device_type_not_empty
        CHECK (device_type <> '');
    END IF;
END
$$;

DO $$
BEGIN
    -- telemetry_events.metric no debe aceptar cadenas vacías
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'telemetry_events_metric_not_empty'
    ) THEN
        ALTER TABLE telemetry_events
        ADD CONSTRAINT telemetry_events_metric_not_empty
        CHECK (metric <> '');
    END IF;

    -- telemetry_events.unit no debe aceptar cadenas vacías
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'telemetry_events_unit_not_empty'
    ) THEN
        ALTER TABLE telemetry_events
        ADD CONSTRAINT telemetry_events_unit_not_empty
        CHECK (unit <> '');
    END IF;
END
$$;