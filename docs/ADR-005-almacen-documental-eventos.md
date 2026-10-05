# ADR 005: Selección de Almacén Documental para Eventos CDRL

## Estado
Aceptado

## Contexto
Se requiere un modelo de almacenamiento capaz de ingerir eventos de telemetría continuos con esquemas flexibles, garantizando consultas eficientes por tipo/fecha y fuente/fecha, además de soportar alta disponibilidad y rechazar duplicados de red.

## Decisión
Se implementa un **Document Store (DynamoDB)** con la siguiente arquitectura:
1. **Llave Primaria (Partition Key):** `eventId` (String). Garantiza la trazabilidad única.
2. **Esquema flexible:** Solo `eventId`, `type`, `source` y `timestamp` son obligatorios a nivel de aplicación; el `payload` es dinámico según el evento.
3. **Índices Secundarios Globales (GSI):** 
   - `TypeTimestampIndex`: PK=`type`, SK=`timestamp`.
   - `SourceTimestampIndex`: PK=`source`, SK=`timestamp`.
4. **Idempotencia:** Las escrituras utilizan `attribute_not_exists(eventId)` para abortar transacciones duplicadas generadas por reintentos de red.

## Consecuencias
- **Positivas:** Escritura veloz, prevención estricta de duplicados, soporte para esquemas JSON anidados y búsquedas eficientes sin necesidad de escanear toda la base de datos.
- **Negativas:** Obliga a conocer de antemano los patrones de consulta (ya cubiertos por los GSIs).