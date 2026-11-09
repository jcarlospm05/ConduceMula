# Etapa 4 — Fichas JPG, guardado y envío

Proyecto: **jcarlospm05/ConduceMula** (NO modificar MuleAgent).
Rama: `feat/fichas-jpg-envio-v1`.
Estado: **INICIADA, PRIMER CHECKPOINT**. No confundir con etapa cerrada.

## Alcance aprobado

- Una ficha JPG por mula, con identidad estable, nombre, proveedor, mulero cuando corresponda, fecha, hora y horómetro; incluir fotografía visible sin cortar números, o motivo de omisión.
- Guardar automáticamente cada JPG junto con la fotografía **original** sin recomprimir, y el paquete `.mule` cifrado, separados por jornada, etapa y revisión.
- Guardar/recuperar tras fallos y permitir reenvío desde historial.
- Compartir todos los JPG y el único `.mule` en una sola acción, sin confirmar entrega al regresar de WhatsApp.
- Suprimir PDF/guardar PDF del recorrido nuevo de captura y cierre. Mantener lectura/restauración de PDF y reportes antiguos en la app.
- En **etapa 5** se simplificará el Administrador y se generarán PDF solo allí. No cambiar ahora el receptor ni eliminar compatibilidad.

## Checkpoint 4.1: generador de JPG

- `apps/operador/lib/cards/mule_jpg_card.dart`: render Flutter (Canvas/TextPainter) a JPG de 1200 × 1740 píxeles, estilo plano, marca MuleAgent y logo PNG oficial si se entrega. Foto del horómetro con `BoxFit.contain` para evitar recortes; omisión visible y documentada.
- `apps/operador/lib/cards/jpg_card_files.dart`: genera una ficha por ticket **completado** de una revisión cerrada. Nombres `ficha_inicio|salida_YYYY-MM-DD_rN_codigo_id.jpg`, archivos privados bajo `artifacts/<revision>/cards`. Escrituras atómicas, comprobación de la huella original antes de usarla y verificación del JPG final. Repetir la operación no recompone archivos ya existentes y devuelve las mismas rutas y huellas.
- `OperatorServices.ensureJpgCards`: punto de entrada reutilizable para el siguiente checkpoint.
- `apps/operador/test/mule_jpg_card_test.dart`: verifica codificación JPG, nombre/revisión, idempotencia, que la foto original no cambia, omisiones y rechazo de fichas incompletas.

**Importante:** el recorrido actual de cierre aún produce PDF y comparte PDF + `.mule`. No está conectado al generador JPG todavía, de forma intencional, para no romper la compatibilidad a mitad de la etapa.

## Próximo checkpoint (4.2)

1. Manifiesto persistente de fichas JPG + paquete cifrado, con hashes y referencia a la revisión, sin exigir PDF para cierres nuevos. Respetar formato histórico de `artifacts` y migraciones/backups actuales.
2. Publicar en `Descargas/MuleAgent/fecha/etapa/revisión` los JPG, originales y `.mule`, y comprobar existencia/integridad antes de informar éxito.
3. Compartir **JPG + .mule** en una operación, repetir desde historial y retirar acciones PDF del nuevo cierre.
4. Actualizar pruebas completas, CI y verificar con WhatsApp en Android físico en la etapa 6.

## Dependencias de compatibilidad

- La tabla histórica `artifacts` tiene columnas PDF obligatorias; **no** crear registros nuevos con valores ficticios ni eliminarla. El nuevo contrato debe coexistir con cierres/respaldos antiguos.
- El receptor Administrador actual tiene rutas `syncOwn` y PDF histórico: adaptar solo después de crear el contrato sin PDF y probar recepción/restauración.
- El paquete `.mule` mantiene autenticidad, integridad, origen y revisión. Los JPG no son sustitutos del paquete cifrado.
- Una foto original no se reemplaza ni recomprime.
- Nunca marcar una copia pública completa antes de verificar sus archivos.

## Criterio de avance

El generador JPG y sus pruebas deben superar el análisis Flutter y el workflow de CI antes de pasar al nuevo contrato y modificar el cierre.
