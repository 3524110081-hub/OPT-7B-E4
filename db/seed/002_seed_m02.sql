-- Caso Normal
INSERT INTO devices (id, device_uid, device_type) 
VALUES ('55555555-5555-5555-5555-555555555551', 'SENSOR-TEMP-02', 'THERMOSTAT');
INSERT INTO telemetry_events (id, device_id, metric, unit, value, observed_at) 
VALUES ('66666666-6666-6666-6666-666666666661', '55555555-5555-5555-5555-555555555551', 'temperature', 'celsius', 25.0, NOW());

-- Caso Vacío
INSERT INTO devices (id, device_uid, device_type) 
VALUES ('55555555-5555-5555-5555-555555555552', 'ACTUATOR-02', 'VALVE');

-- Caso Límite
INSERT INTO devices (id, device_uid, device_type) 
VALUES ('55555555-5555-5555-5555-555555555553', 'X', 'Y');
INSERT INTO telemetry_events (id, device_id, metric, unit, value, observed_at) 
VALUES ('66666666-6666-6666-6666-666666666663', '55555555-5555-5555-5555-555555555553', 'Z', 'W', 10.5, NOW());