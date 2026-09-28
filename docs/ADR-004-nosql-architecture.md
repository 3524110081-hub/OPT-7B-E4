# ADR-004 — Decisión arquitectónica NoSQL

## Estado

Aceptado con validación parcial.

## Contexto

El proyecto CDRL necesita almacenar eventos de telemetría generados de manera continua.

Los eventos pueden incluir:

- identificador del dispositivo;
- tipo de evento o métrica;
- fecha y hora;
- valor;
- metadatos adicionales;
- campos variables dependiendo del tipo de evento.

Además, el sistema debe soportar consultas frecuentes por dispositivo, intervalo temporal y tipo de métrica.

Para M04 se evaluaron cuatro modelos de almacenamiento NoSQL:

- Document;
- Graph;
- Column / Wide-column;
- Object Store.

## Problema

Se requiere seleccionar un modelo de almacenamiento que sea adecuado para los eventos de telemetría de CDRL y que considere:

- consultas representativas;
- escalabilidad;
- rendimiento de escritura;
- flexibilidad del esquema;
- consistencia;
- tolerancia a fallos;
- costo y operación;
- adecuación al caso CDRL.

La decisión no debe basarse solamente en preferencia por una tecnología, sino en una matriz ponderada y evidencia obtenida mediante un prototipo.

## Consultas representativas de CDRL

Las consultas consideradas son:

1. Obtener eventos de un dispositivo durante un intervalo de tiempo.
2. Obtener los últimos eventos de un dispositivo.
3. Filtrar eventos por tipo o métrica.
4. Insertar eventos continuamente.
5. Considerar futuras estadísticas o agregaciones sobre los eventos.

## Alternativas evaluadas

### Document Store

Tecnología representativa de la investigación: MongoDB.

Este modelo permite almacenar documentos con estructuras flexibles, por lo que diferentes eventos pueden contener campos distintos.

Su flexibilidad resulta útil para CDRL debido a que distintos tipos de eventos pueden requerir diferentes atributos.

Hipótesis H1:

> El modelo Document permite almacenar eventos con campos variables y consultarlos por dispositivo y rango temporal.

### Graph Store

Tecnología representativa: Neo4j.

El modelo Graph se orienta principalmente a nodos, relaciones y recorridos entre entidades.

Puede ser útil cuando las consultas principales requieren analizar relaciones complejas entre dispositivos, usuarios, ubicaciones u otras entidades.

En el caso actual de CDRL, las consultas principales se concentran en dispositivo, tipo de evento y tiempo.

Hipótesis H2:

> Graph no proporciona una ventaja clara cuando las consultas no dependen de recorridos complejos entre relaciones.

### Column / Wide-column

Tecnología representativa: Apache Cassandra.

Este modelo está diseñado para arquitecturas distribuidas, altos volúmenes de escritura, replicación y escalabilidad horizontal.

Puede ser especialmente adecuado para grandes cantidades de eventos si la clave de partición y las columnas de ordenamiento se diseñan de acuerdo con las consultas.

Hipótesis H3:

> Wide-column mantiene un comportamiento adecuado al aumentar el volumen de eventos cuando la partición está correctamente diseñada.

### Object Store

Tecnología representativa: Amazon S3.

Un Object Store es apropiado para almacenar grandes cantidades de archivos u objetos y puede ser especialmente útil para históricos, respaldos y almacenamiento masivo.

Sin embargo, las consultas operacionales frecuentes pueden requerir mecanismos adicionales de indexación, catalogación o procesamiento.

Hipótesis H4:

> Object Store permite almacenar grandes volúmenes de información, pero requiere mecanismos adicionales para consultas operacionales frecuentes.

## Criterios de evaluación

Se utilizó una escala de 1 a 5:

- 1 = muy poco adecuado;
- 2 = poco adecuado;
- 3 = adecuado con limitaciones;
- 4 = muy adecuado;
- 5 = excelente adecuación.

Los criterios y pesos utilizados fueron:

| Criterio | Peso |
|---|---:|
| Consultas representativas | 20% |
| Escalabilidad | 20% |
| Rendimiento de escritura | 15% |
| Flexibilidad del esquema | 10% |
| Consistencia | 10% |
| Tolerancia a fallos | 10% |
| Costo y operación | 5% |
| Adecuación al caso CDRL | 10% |
| **Total** | **100%** |

## Matriz ponderada

| Criterio | Peso | Document | Graph | Column | Object Store |
|---|---:|---:|---:|---:|---:|
| Consultas representativas | 20% | 5 | 3 | 5 | 2 |
| Escalabilidad | 20% | 5 | 4 | 5 | 5 |
| Rendimiento de escritura | 15% | 4 | 3 | 5 | 4 |
| Flexibilidad del esquema | 10% | 5 | 4 | 4 | 5 |
| Consistencia | 10% | 4 | 4 | 3 | 3 |
| Tolerancia a fallos | 10% | 5 | 4 | 5 | 5 |
| Costo y operación | 5% | 4 | 3 | 3 | 4 |
| Adecuación al caso CDRL | 10% | 5 | 2 | 5 | 3 |
| **Puntuación ponderada** | **100%** | **4.65/5** | **3.40/5** | **4.60/5** | **3.80/5** |

La matriz inicial identifica a Document y Column como los modelos que presentan mayor adecuación al escenario CDRL.

Document obtuvo una puntuación ponderada de 4.65/5, mientras que Column obtuvo 4.60/5.

Estas puntuaciones se consideran hipótesis arquitectónicas y no mediciones directas de rendimiento.

## Evidencia e hipótesis falsables

### H1 — Flexibilidad y consultas

Para probar parcialmente H1 se utilizó un prototipo basado en DynamoDB Local.

Se insertaron dos eventos del mismo dispositivo con esquemas diferentes.

El primer evento contenía:

- device_id;
- observed_at;
- metric;
- value.

El segundo evento agregó también:

- extra_field.

Ambos eventos fueron almacenados correctamente.

Resultado:

**PASS**

Esto proporciona evidencia de que el prototipo soporta eventos con estructuras variables.

### Consulta por dispositivo y rango temporal

Se ejecutó una consulta para:

- device_id = DEV-001;
- intervalo entre 10:00 y 10:10.

Resultado:

- 2 eventos encontrados.

**PASS**

### Último evento de un dispositivo

Se realizó una consulta ordenada de forma descendente usando `observed_at`.

Se obtuvo correctamente el evento:

- DEV-001;
- observed_at = 2026-09-27T10:05:00Z.

**PASS**

### Consulta por métrica

Se filtraron eventos con:

- metric = temperature.

Resultado:

- 1 evento encontrado.

**PASS**

### Validación de evento inválido

Se intentó insertar un evento sin las claves obligatorias `device_id` y `observed_at`.

DynamoDB rechazó correctamente la operación.

**PASS**

## Resultados de QA

Se implementó:

`tests/test_m04.sh`

con cinco pruebas automatizadas:

1. Caso normal.
2. Caso límite con un único evento.
3. Caso límite con dispositivo inexistente.
4. Fallo declarado con evento inválido.
5. Consulta representativa por métrica.

Resultado:

```text
M04: TODAS LAS PRUEBAS PASARON