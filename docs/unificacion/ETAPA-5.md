# Etapa 5 — Administrador simplificado

**Estado: TERMINADA — implementación integrada y verificada por GitHub Actions.**
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

## Cierre de etapa 5

**5.2 Recepción y respaldos:** `apps/administrador/lib/stage5_services.dart` recibe `.mule` v2 JPG y v1 PDF histórico, descifra, valida y almacena originales y paquete cifrado. Consolida datos sin convertir JPG a PDF ficticio. El respaldo incluye tablas JPG, imágenes sin asociar, exclusiones y archivos verificados; restaura conservando los originales.

**5.3 JPG independientes:** selección por fecha, etapa y supervisor declarado. Validación del archivo, deduplicación SHA-256 y conservación como anexo independiente, sin atribuirlo falsamente a una ficha.

**5.4 Consolidación:** `packages/admin_data/lib/stage5_management.dart` y `Stage5AdminServices.cards` presentan última revisión por jornada, supervisores de origen, avisos de etapa faltante y códigos repetidos, exclusión y reinclusión reversible. Los originales importados son inmutables.

**5.5 PDF administrativo:** la pantalla `ReceivedReportsScreen` ofrece recepción, fecha, etapa, consolidación, exclusiones, JPG independientes, vista previa y generación de PDF por entrada o salida. El flujo unificado no expone cruces ni Excel. Los módulos históricos permanecen para compatibilidad.

**5.6 Verificación:** `apps/muleagent/test/stage5_admin_test.dart` cubre importación real de un `.mule` JPG generado por el Supervisor, reenvío, consolidación, exclusión/reinclusión, PDF, imágenes sueltas, respaldo/restauración y restricción de permisos. `packages/admin_data/test/stage5_management_test.dart`, `jpg_inbox_test.dart` y `jpg_payload_test.dart` comprueban integridad, duplicados, esquema e historial. Las tres acciones de GitHub para el commit `ceb4c90a4598f85ae8233c0b4a0b43b6fb47b46b` concluyeron **success**: Operador, Administrador y MuleAgent modular.

**Criterio de cierre:** código y pruebas aprobados en CI, rama fusionada a `refactor/mule-unificada`. Las pruebas con teléfono Android, instalación/actualización física, firma de distribución y entrega de APK final corresponden a la **etapa 6**, no se presentan como ejecutadas aquí.

**Siguiente paso:** etapa 6 — verificación final y APK única.
