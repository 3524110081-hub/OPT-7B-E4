-- Consultas M03 - demostración de mínimo privilegio
-- Integrante 2: Consultas, Variables de Entorno y Rotación

-- =========================================================
-- 1. Consulta parametrizada de lectura con role_reader
-- =========================================================

SET ROLE role_reader;

PREPARE get_device_by_uid(text) AS
SELECT
    d.device_uid,
    d.device_type,
    t.metric,
    t.value,
    t.unit,
    t.observed_at
FROM devices AS d
LEFT JOIN telemetry_events AS t
    ON d.id = t.device_id
WHERE d.device_uid = $1;

EXECUTE get_device_by_uid(
    'm03-writer-device'
);

DEALLOCATE get_device_by_uid;

RESET ROLE;


-- =========================================================
-- 2. Operación parametrizada de escritura con role_writer
-- =========================================================

SET ROLE role_writer;

PREPARE update_device_type(text, text) AS
UPDATE devices
SET device_type = $1
WHERE device_uid = $2;

EXECUTE update_device_type(
    'SENSOR-M03-ACTUALIZADO',
    'm03-writer-device'
);

DEALLOCATE update_device_type;

RESET ROLE;


-- =========================================================
-- 3. Consulta parametrizada limitada con role_operator
-- =========================================================

SET ROLE role_operator;

PREPARE get_operator_device(text) AS
SELECT
    device_uid,
    device_type
FROM devices
WHERE device_uid = $1;

EXECUTE get_operator_device(
    'm03-writer-device'
);

DEALLOCATE get_operator_device;

RESET ROLE;