# ADR-006 — Evolución documental, auditoría y recuperación

## 1. Estado

Aceptado para el prototipo local de M06.

## 2. Contexto

El proyecto CDRL utiliza un almacén documental basado en DynamoDB Local para gestionar eventos de telemetría.

Durante las semanas anteriores se implementaron operaciones CRUD, consultas mediante índices y validaciones de eventos.

En la Semana 6 se requiere demostrar que el almacén puede evolucionar sin perder compatibilidad con documentos anteriores, registrar modificaciones relevantes y recuperar información después de una falla controlada.

## 3. Problema

Se deben resolver tres necesidades principales:

- Permitir la evolución del esquema documental de versión 1 a versión 2.
- Registrar operaciones de modificación mediante un mecanismo de auditoría.
- Recuperar documentos desde un respaldo después de una falla simulada.

La solución debe ser reproducible y comprobable mediante pruebas automatizadas.

## 4. Decisión arquitectónica

Se adopta una estrategia de coexistencia de versiones, auditoría transaccional y recuperación controlada desde una tabla de respaldo.

Se utilizarán tres tablas:

| Tabla | Función |
|---|---|
| `cdrl_events` | Almacén principal de eventos |
| `cdrl_audit` | Registro de operaciones auditadas |
| `cdrl_events_backup` | Respaldo de documentos sintéticos |

## 5. Evolución documental

El documento original `evt_dr_001` utiliza `schemaVersion = 1` y contiene información de telemetría de temperatura.

La evolución genera un segundo documento, `evt_dr_002`, con `schemaVersion = 2`.

La nueva versión incorpora información adicional, como la unidad de temperatura, y una referencia al documento original mediante `migrationFrom`.

Esta estrategia permite conservar el documento v1 mientras se incorpora el documento v2.

La operación se implementa en `scripts/m06_evolution.sh`.

## 6. Auditoría de operaciones

La auditoría registra la modificación del estado del documento v2 desde `new` hasta `reviewed`.

El proceso utiliza una operación transaccional de DynamoDB para actualizar el documento y generar el registro de auditoría conjuntamente.

Los registros contienen identificador, evento afectado, operación, campo modificado, valores anterior y posterior, actor sintético y fecha.

No se almacenan contraseñas, tokens ni credenciales.

La implementación se encuentra en `scripts/m06_audit.sh`.

## 7. Simulación de falla controlada

Se implementó una simulación que elimina temporalmente el documento sintético `evt_dr_001` del almacén principal.

Antes de realizar la eliminación, el sistema comprueba que existe un respaldo equivalente.

La prueba no elimina la tabla completa ni afecta intencionalmente otros eventos.

La implementación se encuentra en `scripts/m06_failure.sh`.

## 8. Recuperación desde respaldo

El mecanismo de recuperación obtiene el documento desde `cdrl_events_backup` y lo restaura en `cdrl_events`.

Posteriormente compara el contenido restaurado con el respaldo y genera una huella SHA-256 del documento para registrar su integridad.

También mide el tiempo de ejecución de la operación de restauración y verificación, expresado en milisegundos.

La evidencia se registra en `evidence/m06-recovery.json`.

El tiempo medido corresponde a la operación de recuperación del prototipo y no incluye el tiempo transcurrido desde la falla.

## 9. Pruebas automatizadas

Se implementó `tests/test_m06.sh` con las siguientes comprobaciones:

| Prueba | Objetivo |
|---|---|
| Caso normal | Validar el documento v2 |
| Caso límite 1 | Comprobar compatibilidad del documento v1 |
| Caso límite 2 | Verificar el registro de auditoría |
| Fallo declarado | Comprobar recuperación e integridad |
| Consultas indexadas | Verificar consultas usando índices existentes |

Las consultas indexadas utilizan `TypeTimestampIndex` y `SourceTimestampIndex`, definidos previamente en el almacén documental.

## 10. Automatización y resultados

El archivo `scripts/verify_m06.sh` ejecuta el proceso completo de evolución, auditoría, falla, recuperación y pruebas.

Al terminar correctamente, genera los siguientes archivos:

- `artifacts/m06-verify.json`
- `evidence/m06-evidence.json`
- `evidence/m06-recovery.json`
- `evidence/m06-verify-output.txt`

La verificación automatizada de M06 fue ejecutada satisfactoriamente durante las pruebas locales.

## 11. Consecuencias positivas

- Conservación de documentos anteriores.
- Evolución del esquema sin reemplazar el documento original.
- Registro verificable de modificaciones.
- Recuperación comprobable desde un respaldo.
- Medición del tiempo de restauración.
- Automatización de las pruebas.
- Generación de evidencia legible por máquinas.

## 12. Limitaciones

La implementación actual utiliza DynamoDB Local y datos sintéticos.

El mecanismo de respaldo es una copia preparada para la actividad, no un sistema automático de respaldos de producción.

La auditoría implementada cubre la modificación controlada del estado del documento v2; no constituye todavía un historial completo de todas las operaciones del almacén.

La recuperación comprueba la integridad de un fixture específico, pero no representa una restauración completa ante la pérdida de una infraestructura distribuida.

Tampoco se han medido el punto de recuperación real (RPO), el tiempo total de indisponibilidad ni el comportamiento bajo fallos concurrentes.

## 13. Plan de mejora

Como trabajo posterior se propone:

- Implementar migraciones para conjuntos mayores de documentos.
- Ampliar la auditoría a otras operaciones CRUD.
- Automatizar los respaldos y su retención.
- Ejecutar pruebas de recuperación con distintos volúmenes.
- Medir RPO y RTO en escenarios de fallo más representativos.
- Validar el comportamiento en AWS Academy cuando esté disponible.

## 14. Conclusión

La implementación de M06 demuestra, dentro del entorno local de pruebas, un mecanismo funcional de evolución documental, auditoría y recuperación de eventos sintéticos.

Las pruebas automatizadas permiten verificar la compatibilidad entre versiones, la integridad de la restauración y el uso de los índices existentes.

La solución constituye una base reproducible para ampliar las capacidades de resiliencia del almacén documental CDRL.