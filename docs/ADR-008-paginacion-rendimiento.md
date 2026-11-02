# ADR-008: Paginación y rendimiento de consultas mediante índices

- Estado: Aceptado
- Proyecto: CDRL
- Actividad: M08
- Responsable: Integrante 3
- Fecha: 2 de noviembre de 2026

## 1. Contexto

Durante la actividad M08 se evaluó el rendimiento de las operaciones
Scan y Query en DynamoDB Local, utilizando la tabla `cdrl_events`.

Se cargaron 150 documentos sintéticos de telemetría, distribuidos
entre los tipos temperature, humidity y pressure.

Para comparar ambas operaciones se seleccionaron los 50 documentos
correspondientes al tipo `temperature`.

La tabla cuenta con el índice secundario global
`TypeTimestampIndex`, que permite realizar consultas por tipo y
orden temporal.

## 2. Decisión

Se mantiene el uso de Query mediante `TypeTimestampIndex` para
consultas que necesitan recuperar eventos de un tipo específico.

Se recomienda Scan para recorridos completos de la tabla,
inspecciones generales y tareas de mantenimiento.

La paginación debe utilizar `Limit` y `ExclusiveStartKey` para
recuperar resultados por páginas, evitando depender de una única
consulta de gran tamaño.

## 3. Evidencia de rendimiento

Se realizaron tres ejecuciones de calentamiento y 30 mediciones
por operación.

El benchmark comparó las mismas condiciones lógicas:
recuperar los documentos cuyo tipo es `temperature`.

| Métrica | Scan | Query |
|---|---:|---:|
| Documentos encontrados | 50 | 50 |
| Documentos examinados | 159 | 50 |
| p50 | 920.851 ms | 908.384 ms |
| p95 | 1147.861 ms | 1138.656 ms |
| Capacidad reportada | 2.5 | 1.0 |

### Método de cálculo de percentiles

Se utilizó el método Nearest Rank:

R = ceil(p * n)

Donde:
- p representa el percentil expresado entre 0 y 1.
- n representa el número de mediciones.
- R representa la posición del dato ordenado.

Con 30 mediciones:
- p50 corresponde a la posición 15.
- p95 corresponde a la posición 29.

### Interpretación

Ambas operaciones devolvieron los mismos 50 documentos.

Query examinó 50 documentos, mientras que Scan examinó 159.
Esto representa aproximadamente 68.6% menos documentos examinados.

La capacidad reportada fue 1.0 para Query y 2.5 para Scan,
una reducción del 60% en este experimento.

Sin embargo, Query no obtuvo una menor latencia:
- Scan registró p50 de 949.690 ms.
- Query registró p50 de 950.125 ms.
- Scan registró p95 de 1447.358 ms.
- Query registró p95 de 1683.360 ms.

Por lo tanto, no se observó una mejora de latencia de Query
en este entorno de prueba.

Los tiempos incluyen el inicio y ejecución de procesos AWS CLI,
además del procesamiento de DynamoDB Local. Estos factores
pueden influir significativamente en las mediciones.

La capacidad reportada por DynamoDB Local no representa
directamente un costo monetario de producción en AWS.

## 4. Ventajas de utilizar índices

- Permiten localizar registros mediante atributos específicos.
- Reducen la cantidad de documentos examinados en consultas selectivas.
- Pueden reducir el consumo de capacidad de lectura.
- Facilitan la consulta ordenada por timestamp.
- Evitan recorrer toda la tabla para búsquedas que coinciden
  con las claves del índice.

## 5. Desventajas y costos

- Los índices secundarios requieren almacenamiento adicional.
- Las escrituras deben mantener actualizados los índices.
- Pueden incrementar el consumo de capacidad de escritura.
- Su diseño requiere seleccionar adecuadamente las claves
  de partición y ordenamiento.
- Un índice mal diseñado puede provocar distribuciones
  desiguales de carga o consultas poco eficientes.

## 6. Pruebas QA

Se ejecutaron los siguientes casos:

| Caso | Resultado |
|---|---|
| Consulta normal mediante Query | PASS |
| Límite suficiente sin página siguiente | PASS |
| Cursor inválido rechazado | PASS |

También se ejecutó una prueba de paginación con `Limit`,
`ExclusiveStartKey` e inserción de un documento entre lecturas.

La segunda página se recuperó correctamente con dos elementos.

## 7. Consecuencias

Se conserva `TypeTimestampIndex` como mecanismo de consulta
para eventos por tipo y timestamp.

Aunque el experimento no demostró una reducción de latencia,
sí mostró una reducción en documentos examinados y capacidad
reportada.

El uso de índices debe justificarse según los patrones de consulta,
el volumen de información, el costo de almacenamiento y el costo
de mantenerlos durante las escrituras.

## 8. Limitaciones

Las pruebas se realizaron sobre DynamoDB Local y no representan
una evaluación definitiva del rendimiento de una instancia
de Amazon DynamoDB en producción.

Los resultados de latencia están sujetos al entorno local,
al sistema operativo, al proceso AWS CLI y a la carga de ejecución.

Para una evaluación de producción se recomienda repetir las pruebas
con infraestructura AWS real, tamaños de datos mayores y métricas
de latencia medidas desde el cliente sin incluir innecesariamente
el inicio de procesos externos.

## 9. Artefactos de evidencia

- `artifacts/m08-baseline-scan.json`
- `artifacts/m08-benchmark.json`
- `artifacts/m08-verify.json`
- `scripts/m08_benchmark.sh`
- `scripts/m08_pagination.sh`
- `tests/test_m08.sh`
- `scripts/verify_m08.sh`
