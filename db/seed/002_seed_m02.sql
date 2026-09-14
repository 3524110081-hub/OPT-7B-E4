-- 1. Caso Normal: Dispositivo con datos completos
INSERT INTO devices (id, device_uid, device_type) 
VALUES ('55555555-5555-5555-5555-555555555551', 'SENSOR-TEMP-02', 'THERMOSTAT');
INSERT INTO telemetry_events (id, device_id, metric, unit, value) 
VALUES ('66666666-6666-6666-6666-666666666661', '55555555-5555-5555-5555-555555555551', 'temperature', 'celsius', 25.0);

-- 2. Caso Vacío: Dispositivo sin eventos de telemetría registrados
INSERT INTO devices (id, device_uid, device_type) 
VALUES ('55555555-5555-5555-5555-555555555552', 'ACTUATOR-02', 'VALVE');

-- 3. Caso Límite: Cadenas de 1 solo carácter (al borde de la cadena vacía)
INSERT INTO devices (id, device_uid, device_type) 
VALUES ('55555555-5555-5555-5555-555555555553', 'X', 'Y');
INSERT INTO telemetry_events (id, device_id, metric, unit, value) 
VALUES ('66666666-6666-6666-6666-666666666663', '55555555-5555-5555-5555-555555555553', 'Z', 'W', 10.5);