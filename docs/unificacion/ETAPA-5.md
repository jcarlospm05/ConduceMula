# Etapa 5 — Administrador simplificado

**Estado: INICIADA — checkpoint 5.1, no cerrada.**
**Repositorio único:** `jcarlospm05/ConduceMula`.
**Base aprobada:** `refactor/mule-unificada` (etapas 1–4 completas).
**Rama de trabajo:** `feat/administrador-etapa5`.
**Imagen oficial:** `LOGO_MULEAGENT_V1`; **interfaz:** `INTERFAZ_MULEAGENT_V1`.

## Objetivo aprobado

- Importar archivos `.mule` **nuevos** (con JPG) y archivos JPG por fecha y etapa.
- Reunir informes de varios supervisores, conservando origen y versiones.
- Evitar duplicados y detectar conflictos de revisiones.
- Identificar jornadas incompletas o con diferencias, sin inventar datos.
- Seleccionar/excluir fichas de un consolidado, con botón «Volver a incluir».
- Crear PDF **solo** para Administrador: informe de entrada o de salida.
- Retirar del flujo administrativo nuevo los cruces manuales y Excel.
- Preservar recepción de `.mule` antiguos con PDF y todos los archivos originales.

## Checkpoint 5.1: compatibilidad y almacenamiento nuevo

- `packages/admin_data/lib/jpg_payload.dart`: parser independiente `JpgReceivedReport` del contrato `delivery.version=2`. Valida origen, etapa, fecha, revisión, fichas completadas, pares evidencia/ticket, nombres, JPG, huellas SHA-256, rutas seguras, lista de archivos exacta y tamaño total. No fabrica PDF ni interpreta datos incompletos como completos.
- `packages/admin_data/lib/jpg_inbox.dart`: almacén SQLite **separado**, con `admin_jpg_revisions` y `admin_jpg_files`, triggers de inmutabilidad y control de versión en `mule_feature_versions`. No altera `admin_revisions.pdf_path NOT NULL` ni los disparadores históricos. Reenvíos idénticos son idempotentes; cambios en revisiones anteriores provocan un error, sin sobrescribir.
- `apps/muleagent/lib/application/unified_bundle.dart`: inicialización aditiva del esquema en instalaciones nuevas o existentes, después de validar el esquema administrativo histórico.
- Pruebas de contrato y persistencia: legados PDF, integridad JPG, revisiones/colisiones, reenvíos, dos supervisores, almacenamiento inmutable.

### Pendiente en el checkpoint 5.2

Conectar el receptor `AdminServices`/UI a `JpgReceivedReport`: descifrado, almacenamiento privado original con SHA-256 y transacción de importación, bandeja de reportes JPG e indicador de origen. Incluir estos registros y archivos en respaldos/restauración administrativos antes de habilitar el uso real.

### Checkpoints siguientes

5.3. Importación de JPG sueltos por fecha/etapa con fuente e integridad, sin asociarlos automáticamente a jornadas sin identificación validada.

5.4. Vista consolidada por fecha/etapa y supervisor, exclusiones reversibles, duplicados/conflictos, aviso de jornadas incompletas. Solo datos realmente verificados.

5.5. PDF de Administrador con fichas seleccionadas; retirar Excel y cruces del recorrido visible. Preservar históricos y registros de auditoría.

5.6. Pruebas Flutter, actualización de datos/roles, interoperabilidad con `.mule` 1 y 2, compilación APK debug única; integración en `refactor/mule-unificada` y documentación de cierre. Validación Android físico y firma final en etapa 6.

**No usar en producción una etapa incompleta.** El checkpoint 5.1 añade parser y almacenamiento, pero todavía no habilita importación de JPG en pantalla.
