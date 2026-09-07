# Contrato de Datos: Telemetría CDRL

Este documento define la estructura estricta y las reglas de validación para la ingesta de datos de telemetría en el sistema CDRL.

## Entidades y Modelo Relacional

### 1. Tabla: `devices`
Representa el origen físico o lógico que emite la métrica.
- `id` (UUID, PK): Identificador interno autogenerado.
- `device_uid` (VARCHAR 100, UNIQUE, NOT NULL): Identificador externo único del dispositivo.
- `device_type` (VARCHAR 50, NOT NULL): Clasificación del dispositivo.
- `created_at` (TIMESTAMPTZ): Fecha de registro en el sistema.

### 2. Tabla: `telemetry_events`
Representa una medición individual en el tiempo.
- `id` (UUID, PK): Identificador interno autogenerado.
- `device_id` (UUID, FK, NOT NULL): Referencia a `devices.id`. Se elimina en cascada.
- `metric` (VARCHAR 100, NOT NULL): Nombre de la métrica. No puede estar vacío.
- `value` (NUMERIC, NOT NULL): Valor de la medición. Si es `cpu_usage`, se restringe a un rango de 0 a 100.
- `unit` (VARCHAR 30, NOT NULL): Unidad de medida. No puede estar vacío.
- `observed_at` (TIMESTAMPTZ, NOT NULL): Marca de tiempo real de la lectura.
- `created_at` (TIMESTAMPTZ): Marca de tiempo de inserción en la BD.