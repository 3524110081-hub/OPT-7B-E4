# M09 — Seguridad NoSQL y auditoría

## 1. Objetivo

Implementar y verificar controles de autorización para operaciones sobre
la colección `cdrl_events`, registrar las decisiones de acceso en
`cdrl_audit` y comprobar que la auditoría no almacene información
sensible ni secretos.

Las pruebas se ejecutaron utilizando DynamoDB Local.

## 2. Controles de acceso

La función `execute_secure_op` de
`scripts/m09_security_audit.sh` aplica las siguientes reglas:

| Rol | Operaciones permitidas | Operaciones rechazadas |
|---|---|---|
| `admin` | Todas las operaciones contempladas por el controlador | Ninguna por restricción de rol |
| `readonly_user` | `GetItem`, `Query`, `Scan` | Escrituras y eliminaciones |
| Otros roles | Ninguna | Todas |

La política sigue el principio de denegación por defecto: cualquier
operación que no esté expresamente permitida se rechaza.

**Alcance:** estos controles se aplican en la capa de ejecución del
script Bash. No representan políticas IAM nativas ni sustituyen la
autenticación y autorización del servicio DynamoDB en producción.

## 3. Auditoría

Las decisiones de autorización se registran en la tabla `cdrl_audit`.

Cada registro generado por M09 contiene:

- `auditId`: identificador único del registro.
- `actorId`: identificador del actor.
- `actorRole`: rol del actor.
- `action`: operación solicitada.
- `resource`: recurso sobre el que se solicita la operación.
- `timestamp`: fecha y hora UTC.
- `result`: decisión de autorización (`ALLOW` o `DENY`).

No se registra el contenido de los elementos consultados o enviados
como parte de las operaciones.

El campo `result` representa la decisión de autorización y no garantiza
que una operación permitida haya terminado correctamente. La ejecución
de la operación se comprueba por separado.

## 4. Remediación de seguridad

Durante la revisión del script se identificó el uso de `eval` para
ejecutar comandos almacenados en cadenas de texto.

Esta implementación podía provocar que una cadena manipulada se
interpretara como código de shell.

La remediación consistió en:

1. Eliminar las variables que almacenaban comandos completos como texto.
2. Recibir el comando y sus argumentos como parámetros separados.
3. Utilizar `shift 4` para separar los metadatos de auditoría.
4. Ejecutar el comando mediante `"$@"`, sin reinterpretar la cadena
   como código de shell.
5. Comprobar el código de salida de la operación autorizada.

La modificación se encuentra en
`scripts/m09_security_audit.sh`, dentro de `execute_secure_op`.

## 5. Pruebas de calidad y seguridad

El verificador `scripts/verify_m09.sh` ejecuta los siguientes casos:

| Prueba | Resultado esperado |
|---|---|
| Escritura con rol `admin` | Permitida y persistida |
| Lectura con rol `readonly_user` | Permitida |
| Eliminación con rol `readonly_user` | Rechazada |
| Escritura con rol `unknown_role` | Rechazada y sin persistencia |
| Lectura con rol `unknown_role` | Rechazada |
| Campos requeridos de auditoría | Presentes |
| Campos sensibles en auditoría | No detectados |
| Patrones comunes de secretos en valores | No detectados |

También se comprueba que la escritura autorizada permanezca en
`cdrl_events` y que la escritura no autorizada no se encuentre en la
tabla.

La búsqueda de patrones de secretos es una comprobación básica y no
garantiza la detección de cualquier secreto posible.

## 6. Resultados

La última ejecución de `scripts/verify_m09.sh` reportó:

- 10 pruebas aprobadas.
- 0 pruebas fallidas.
- 5 registros nuevos de auditoría identificados.
- Resultado general: `PASSED`.

La validación de sintaxis de los scripts Bash también terminó sin
errores.

## 7. Archivos relacionados

**Implementación**
- `scripts/m09_security_audit.sh`
- `scripts/verify_m09.sh`

**Artefactos**
- `artifacts/m09-verify.json`

**Evidencias**
- `evidence/m09-evidence.json`
- `evidence/m09-verify-output.txt`

## 8. Conclusión

Se implementaron y probaron reglas de autorización por rol, denegación
por defecto y registro de decisiones de acceso. Se corrigió el uso de
`eval` mediante ejecución directa de argumentos con `"$@"`.

Las pruebas de M09 finalizaron satisfactoriamente en DynamoDB Local.
Para un entorno productivo sería necesario complementar este controlador
con autenticación, permisos aplicados en el servicio y controles de
acceso administrados por la infraestructura.
