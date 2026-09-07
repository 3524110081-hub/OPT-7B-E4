# ADR-001 — Stack tecnológico y ejecución de datos

## Estado

Aceptado

## Contexto

CDRL requiere un entorno de base de datos relacional reproducible que pueda
ejecutarse localmente y que mantenga compatibilidad con un despliegue en la nube.

## Decisión

Se utiliza PostgreSQL 16 como sistema gestor de base de datos relacional.

Docker Compose proporciona un entorno local reproducible.

Los cambios en la estructura de la base de datos se representan mediante
archivos de migración SQL.

Los datos sintéticos utilizados para el desarrollo se representan mediante
archivos seed SQL.

Los scripts de Bash automatizan la ejecución de las migraciones, la carga de
datos seed y las verificaciones.

El Makefile proporciona la interfaz común requerida:

- `make setup`
- `make verify`
- `make run`

## Lenguaje de la aplicación

El equipo seleccionó JavaScript con Node.js como tecnología para el desarrollo
de la aplicación.

Node.js permite utilizar JavaScript del lado del servidor y facilita la integración
con PostgreSQL mediante librerías y controladores disponibles en su ecosistema.

Además, su uso permite desarrollar scripts y servicios de manera sencilla,
manteniendo una estructura compatible con entornos locales y despliegues en la nube.

La elección de Node.js también permite mantener separada la lógica de la aplicación
de la configuración de la base de datos, mientras que Docker Compose proporciona
el entorno reproducible necesario para PostgreSQL.

## Justificación

PostgreSQL proporciona integridad relacional, restricciones y compatibilidad
con entornos administrados de bases de datos en la nube.

Docker Compose permite que todos los integrantes del equipo puedan reproducir
el mismo entorno de base de datos de manera consistente.

Los scripts automatizados reducen la configuración manual y permiten que las
verificaciones puedan ejecutarse de manera repetible.

## Alternativas consideradas

### Configuración manual de la base de datos

Se descartó debido a que dificultaría la reproducción consistente del entorno
entre los diferentes integrantes del equipo.

### Instalación directa de PostgreSQL en cada equipo

Se descartó como estrategia principal de desarrollo debido a que las diferencias
entre sistemas operativos, versiones y configuraciones locales podrían generar
resultados inconsistentes.

## Consecuencias

Todos los cambios realizados en el esquema de la base de datos deben estar
representados mediante migraciones.

Los datos utilizados para las pruebas y el desarrollo deben ser sintéticos.

Las credenciales, tokens, información personal y cadenas de conexión reales
no deben almacenarse en el repositorio Git.