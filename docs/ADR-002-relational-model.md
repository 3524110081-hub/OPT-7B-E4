# ADR-002 — Modelo relacional y validación de integridad para M02

## Estado

Aceptado.

## Contexto

En el hito M02 del proyecto Cloud Data Reliability Lab (CDRL) se requiere
implementar un modelo relacional operativo para almacenar dispositivos y
eventos de telemetría.

Además del almacenamiento de datos, el modelo debe garantizar la integridad
de la información mediante restricciones aplicadas directamente en la base
de datos.

La solución también debe cumplir con los siguientes requisitos:

- Migraciones reproducibles e idempotentes.
- Datos sintéticos para pruebas.
- Consultas parametrizadas.
- Validación de caso normal.
- Validación de caso vacío.
- Validación de valores límite.
- Validación de un fallo declarado.
- Generación de resultados machine-readable.
- Compatibilidad con los comandos:
  - `make setup`
  - `make verify`
  - `make run`

Para el entorno local se utiliza PostgreSQL 16 ejecutado mediante Docker
Compose.

## Decisión

Se decidió mantener PostgreSQL como sistema gestor de base de datos
relacional para el proyecto.

El modelo principal está compuesto por las tablas `devices` y
`telemetry_events`.

### Tabla devices

La tabla `devices` almacena la información básica de los dispositivos.

Se utilizan las siguientes restricciones:

- `PRIMARY KEY` para identificar cada dispositivo mediante UUID.
- `UNIQUE` para evitar dispositivos con el mismo `device_uid`.
- `NOT NULL` para evitar valores nulos en los campos obligatorios.
- `CHECK` para impedir cadenas vacías en `device_uid`.
- `CHECK` para impedir cadenas vacías en `device_type`.

### Tabla telemetry_events

La tabla `telemetry_events` almacena las mediciones producidas por los
dispositivos.

Se utilizan las siguientes restricciones:

- `PRIMARY KEY` mediante UUID.
- `FOREIGN KEY` hacia la tabla `devices`.
- `ON DELETE CASCADE` para eliminar los eventos asociados cuando se elimina
  un dispositivo.
- `NOT NULL` en los campos obligatorios.
- `CHECK` para impedir cadenas vacías en `metric`.
- `CHECK` para impedir cadenas vacías en `unit`.
- Una restricción para que la métrica `cpu_usage` únicamente acepte valores
  entre 0 y 100.

De esta manera, las reglas de integridad son verificadas directamente por
PostgreSQL y no dependen únicamente de la aplicación.

## Migraciones

Las modificaciones del esquema se realizan mediante archivos SQL versionados
dentro del directorio:

`db/migrations/`

Las migraciones utilizan mecanismos como `CREATE TABLE IF NOT EXISTS` y
validaciones sobre `pg_constraint` antes de agregar nuevas restricciones.

Esto permite ejecutar nuevamente las migraciones sin producir errores por
objetos que ya existen.

Por ejemplo, la migración correspondiente a M02 verifica si una restricción
ya está registrada antes de intentar crearla.

## Datos seed

Los datos utilizados para las pruebas se encuentran en:

`db/seed/`

Los registros son datos sintéticos y representan diferentes escenarios de
prueba.

Para permitir que `make setup` pueda ejecutarse más de una vez, los INSERT
utilizan:

`ON CONFLICT DO NOTHING`

De esta forma, si un registro ya existe, PostgreSQL evita insertarlo de nuevo
sin provocar un error por clave duplicada.

## Consultas parametrizadas

Para demostrar el uso de consultas parametrizadas se utiliza la funcionalidad
`PREPARE` y `EXECUTE` de PostgreSQL.

La consulta recibe como parámetro el UUID de un dispositivo y recupera la
telemetría asociada.

El parámetro se representa mediante `$1`, evitando concatenar directamente el
valor dentro de la consulta.

Ejemplo conceptual:

```sql
PREPARE get_device_telemetry (uuid) AS
    SELECT d.device_uid, t.metric, t.value
    FROM devices d
    LEFT JOIN telemetry_events t ON d.id = t.device_id
    WHERE d.id = $1;