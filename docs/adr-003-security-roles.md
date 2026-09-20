# ADR-003 — Gestión y rotación de secretos para roles M03

## Contexto

El proyecto M03 implementa un modelo de mínimo privilegio mediante
los roles `role_migrator`, `role_writer`, `role_reader` y
`role_operator`.

Las credenciales no deben almacenarse directamente en el repositorio.
El archivo `.env.example` únicamente contiene nombres de variables y
valores sintéticos de ejemplo.

## Decisión

Las credenciales de los roles se manejarán mediante variables de
entorno.

Las variables utilizadas son:

- `DB_MIGRATOR_USER`
- `DB_MIGRATOR_PASSWORD`
- `DB_WRITER_USER`
- `DB_WRITER_PASSWORD`
- `DB_READER_USER`
- `DB_READER_PASSWORD`
- `DB_OPERATOR_USER`
- `DB_OPERATOR_PASSWORD`

Los valores reales no deben versionarse en Git.

El archivo `.env.example` sirve únicamente como plantilla de
configuración y utiliza valores sintéticos.

## Rotación

La rotación de credenciales se realizará reemplazando las contraseñas
por nuevos valores fuera del repositorio.

El procedimiento general es:

1. Generar una nueva contraseña.
2. Cambiar la contraseña del rol correspondiente en PostgreSQL.
3. Actualizar la variable de entorno utilizada por el servicio.
4. Reiniciar el servicio que utiliza las credenciales.
5. Verificar que el acceso autorizado continúa funcionando.
6. Verificar que los permisos no autorizados continúan siendo
   rechazados.

## Restricciones de seguridad

No se deben almacenar en Git:

- contraseñas reales;
- tokens;
- claves de acceso;
- cadenas de conexión con credenciales;
- datos personales.

Los archivos de configuración versionados deben contener solamente
valores sintéticos o variables de entorno.

## Justificación

El uso de variables de entorno permite separar la configuración del
código y evita que las credenciales queden expuestas en el historial
del repositorio.

La separación de roles también permite aplicar mínimo privilegio:
cada usuario utiliza únicamente los permisos necesarios para su
función.

## Evidencia

La estrategia será validada mediante las pruebas automatizadas de
M03, incluyendo operaciones permitidas y casos de acceso denegado.