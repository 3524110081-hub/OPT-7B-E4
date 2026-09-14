-- Demostración de consultas parametrizadas seguras
PREPARE get_device_telemetry (uuid) AS
    SELECT d.device_uid, t.metric, t.value 
    FROM devices d
    LEFT JOIN telemetry_events t ON d.id = t.device_id
    WHERE d.id = $1;

-- Ejecución de los casos
EXECUTE get_device_telemetry('55555555-5555-5555-5555-555555555551'); -- Caso normal
EXECUTE get_device_telemetry('55555555-5555-5555-5555-555555555552'); -- Caso vacío
EXECUTE get_device_telemetry('55555555-5555-5555-5555-555555555553'); -- Caso límite