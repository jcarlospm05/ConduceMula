# Etapa 4 — Fichas JPG, guardado y envío

**ESTADO: COMPLETADA** — 9 de noviembre de 2026.
**Proyecto:** `jcarlospm05/ConduceMula` (MuleAgent original intacto).
**Rama integrada:** `refactor/mule-unificada`.
**PR de integración:** https://github.com/jcarlospm05/ConduceMula/pull/2
**Merge:** `9b327c8cc7033d92cdefb09b5f478b0ceb453d44`.

## Funcionalidad entregada

1. **Una ficha JPG por mula**: captura datos, etapa, fecha, revisión, identificación única, proveedor, mulero cuando aplique, hora, horómetro y fotografía visible sin recortar números; muestra motivo si la foto fue omitida. JPG de 1200 × 1740 y estilo flat con el PNG oficial `LOGO_MULEAGENT_V1`.
2. **Fotos originales intactas**: se verifican con SHA-256 antes de construir la ficha; se guardan sin recomprimir ni reemplazar.
3. **Archivo `.mule` cifrado nuevo**: contiene los datos de la revisión, originales y fichas JPG con manifiesto `delivery.version=2` e identidad y huella por ticket. No se genera PDF para cierres nuevos.
4. **Guardado automático**: JPG de todas las mulas, originales y `.mule` en `Descargas/MuleAgent/AAAA-MM-DD/inicio|salida/revisión`. Android verifica hashes de origen y destino; no se registra éxito si falta algún archivo. Se puede recuperar una copia interrumpida desde Carpeta de reportes.
5. **Envío y reenvío**: una sola acción abre compartir con **todos los JPG + un `.mule`**; las fotos originales permanecen en Descargas y dentro del paquete cifrado. Desde el historial se puede repetir el envío sin contador ni estado «pendiente de envío» ni confirmación al regresar de WhatsApp.
6. **Interfaz**: se retiraron los botones «Ver e imprimir PDF», «Guardar copia en Descargas» y «Guardar PDF y archivo cifrado» del recorrido unificado de cierre; se mantiene la recuperación en Carpeta de reportes. El Operador histórico y los PDF anteriores no se borran.
7. **Respaldo/restauración**: el manifiesto local versionado, JPG y paquete se incluyen en los respaldos cifrados, y la restauración verifica que correspondan a la misma revisión. No se cambia el esquema SQLite ni se fabrican rutas PDF para reportes nuevos.

## Código principal

- `apps/operador/lib/cards/mule_jpg_card.dart`: representación JPG.
- `apps/operador/lib/cards/jpg_card_files.dart`: creación idempotente, nombres y validaciones.
- `apps/operador/lib/delivery/mule_delivery.dart`: empaquetado, guardado, recuperación y compartir.
- `apps/muleagent/lib/application/unified_capture_services.dart`: integración para Supervisor/Administrador y respaldo.
- `apps/operador/lib/main.dart`: recorrido actualizado del cierre.
- `packages/mule_android/src/main/kotlin/com/muleagent/platform/PublicReports.kt`: explicación de la carpeta de Descargas.
- `apps/operador/test/mule_jpg_card_test.dart` y `apps/muleagent/test/stage4_delivery_test.dart`: pruebas nuevas.

## Validación de cierre

**GitHub Actions — ejecución unificada:** https://github.com/jcarlospm05/ConduceMula/actions/runs/42693235907 — **success**.

- 6 pruebas de perfiles.
- 12 pruebas de datos compartidos.
- 11 pruebas de datos administrativos.
- 15 pruebas de captura/archivos (incluidas JPG).
- 3 pruebas de interoperabilidad del receptor histórico.
- 13 pruebas de aplicación unificada y migración (incluidas recuperación, manifiesto, respaldo y paquete sin PDF).

**Total: 60 pruebas aprobadas.** Flutter Analyze sin incidencias. `flutter build apk --debug` de la **única app Flutter unificada** completado. Los workflows separados de Operador y Administrador también terminaron con resultado satisfactorio. Estas compilaciones de depuración no sustituyen la APK de producción firmada.

## Límites y continuidad

- **Etapa 5**: actualizar la recepción del Administrador para importar los **nuevos** `.mule` con manifiesto JPG, aceptar JPG externos, consolidar varios supervisores, exclusiones reversibles y PDF administrativo de entrada/salida. El receptor histórico actual sigue leyendo paquetes que contienen PDF, pero todavía **no importa el formato nuevo de la etapa 4**. La sincronización administrativa de cierres nuevos se aplaza deliberadamente para no generar PDF durante la captura.
- **Etapa 6**: verificar en Android físico la compartición de adjuntos mixtos en WhatsApp, descargas reales, apertura de imágenes, actualización de instalaciones con datos, permisos, firma y entrega de una APK ZIP.

**Conclusión:** la etapa 4 se cierra por implementación, pruebas automatizadas y compilación Android. No se declara realizada una prueba de envío/recepción real por WhatsApp ni la compatibilidad de importación del nuevo formato; corresponden a las etapas 5 y 6.
