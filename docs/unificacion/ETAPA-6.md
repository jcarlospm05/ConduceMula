# Etapa 6 — Validación final y APK única

**Estado: ETAPA 6 EN CORRECCIÓN DE CAMPO — checkpoint 6.1 compiló, pero la APK 1.2.0+7 presentó fallos reales de adjuntos y proporción de fotos. Nueva candidata 1.2.1+8 pendiente de CI y aceptación Android física.**
**Repositorio oficial:** `jcarlospm05/ConduceMula` (no editar `jcarlospm05/MuleAgent`).
**Base:** `refactor/mule-unificada` con etapas 1–5 integradas.
**Rama:** `feat/etapa6-validacion-apk`.
**Única aplicación Android:** `apps/muleagent`, identificador `com.muleagent.operador`.

## Entregables técnicos

- Flutter Analyze + pruebas de perfiles, bases de datos, captura, importación, JPG, PDF administrativo, restauración y seguridad; aplicación unificada.
- Compilación `flutter build apk --debug` y verificación con `apksigner` y `aapt` del identificador, versión y certificado.
- **ZIP candidato para prueba de campo** adjuntado a GitHub Actions: APK de depuración, SHA-256, metadatos del certificado y esta guía.
- Preparación de firma de producción mediante secretos en GitHub, sin claves incrustadas en el repositorio.
- Prueba de discrepancias entrada/salida contando **solo fichas incluidas**; igualdad de cantidades no implica coincidencia de identidad.

## Riesgo de actualización y protección de datos

1. **No desinstalar el Operador anterior antes del respaldo.** La aplicación unificada reutiliza el mismo identificador Android y la misma base `operador.db` y clave local `local_database_key_v1`.
2. Android solo permite actualizar una aplicación conservando sus datos cuando **el identificador y el certificado de firma son compatibles** y el `versionCode` aumenta. Un APK debug construido con una clave diferente falla al actualizar, aunque comparta el identificador.
3. La firma de desarrollo del antiguo Operador puede recuperarse de la caché de GitHub solo si está accesible al workflow; no existe garantía de ello. El ZIP candidato describe el certificado usado. **No declarar compatible con actualización hasta comparar certificados con la APK instalada.**
4. La firma de producción debe conservarse de forma permanente; los secretos de GitHub se configuran fuera del código. Nunca subir un `.jks`, contraseña o clave real al repositorio.
5. La aplicación no recupera automáticamente la clave de SQLite al reinstalar o cambiar de teléfono. Se requiere exportar y restaurar respaldo íntegro antes de migrar.

## Matriz de prueba en teléfono Android — pendiente de ejecución real

- [ ] **Instalación nueva:** se instala, aparece el logo oficial `LOGO_MULEAGENT_V1`, inicia sin fallos ni permisos excesivos.
- [ ] **Actualización sin pérdida:** con copia de respaldo y certificado coincidente, actualizar sobre Operador, verificar jornada abierta, fotos originales, historial, SQLite, clave y ajustes.
- [ ] **Supervisor:** configurar y reiniciar; no puede entrar al receptor administrativo ni escalar permisos.
- [ ] **Administrador:** puede alternar a Supervisor y volver; conserva datos, roles y clave local; no se habilitan cruces ni Excel.
- [ ] **Tema claro/oscuro:** alternar y reiniciar; verificar contraste, teclado numérico, campos de hora/minuto, fotos y logo.
- [ ] **Captura entrada y salida:** foto completa del horómetro y sin recortes, hora, cierre, revisión posterior, JPG por mula y `.mule` cifrado.
- [ ] **Descargas:** carpeta por fecha/etapa/revisión con todos los JPG, originales y un `.mule`; abrir los archivos, verificar copias SHA-256 y recuperación si se interrumpe.
- [ ] **WhatsApp:** compartir JPG + `.mule` juntos en Android real, confirmar que el destinatario recibió **todos** los adjuntos con sus nombres; reenvío desde historial.
- [ ] **Recepción:** Administrador importa `.mule` de etapa 4 y PDF histórico de etapa anterior, detecta duplicados, conserva origen; un JPG suelto no se atribuye automáticamente a ficha.
- [ ] **Consolidado:** varios supervisores, fecha/etapa, excluida/reincluida, diferencias de cantidades, PDF administrativo; auditar reportes incompletos.
- [ ] **Recuperación:** exportar respaldo con JPG y fotos, restaurar en segunda instalación, comprobar permisos, no duplicación y archivos.
- [ ] **Seguridad:** clave errónea no importa, archivo manipulado no se acepta, instalación Supervisor no recibe; APK no contiene credenciales.

**La matriz anterior es un protocolo, no una declaración de pruebas realizadas.** Los resultados físicos deben registrarse antes de cerrar la etapa como lista para producción.

## Firma y distribución

El ZIP de GitHub Actions es una **APK de depuración para pruebas**, no una APK definitiva de producción. Una APK firmada de producción y un ZIP final requieren instalar una clave propia estable mediante secretos protegidos en GitHub y repetir las pruebas de instalación/actualización. La identidad de firma se valida con `apksigner` y se incluye en `CERTIFICADO.txt`.

## Criterios de cierre

1. CI completo verde en la rama final (tests, Flutter Analyze, build Android, verificación de certificado y ZIP descargable).
2. Pruebas de instalación y envío real documentadas en al menos un Android físico.
3. Firma apta para actualización o procedimiento de migración validado; respaldo recuperable.
4. Entrega APK + ZIP, huellas y guía, con firma indicada explícitamente.
5. Plan maestro actualizado e integración revisada en `refactor/mule-unificada`.

No dar por finalizada la etapa 6 ni distribuir como producción una APK debug sin completar los puntos físicos y la firma correspondiente.


## Evidencia de checkpoint técnico 6.1 — 10 de noviembre de 2026

**GitHub Actions oficial:** https://github.com/jcarlospm05/ConduceMula/actions/runs/42795188150 — **success**.

- 78 pruebas automatizadas aprobadas: perfiles (6), datos compartidos (12), datos administrativos (24), captura y guardado (15), receptor histórico (3), aplicación unificada, migración y aceptación (18).
- Flutter Analyze de todos los módulos sin incidencias.
- `flutter build apk --debug` completado; `apksigner` confirmó firma APK v2. `aapt` confirmó `com.muleagent.operador`, `versionName=1.2.0`, `versionCode=7`, Android minSdk 24.
- Workflows independientes de Operador y Administrador: **success**.
- APK candidata: `MuleAgent-ConduceMula-1.2.0-b7-rc6.apk`, SHA-256 `43ffc6bc6b9a88fe352d00e9b7c6f38385fdd0853f2e73dc2821a6cebd8ab452`.
- Certificado debug de esta ejecución: SHA-256 `d0564b26e4095974f659eea1cfe2e42384d2341f963059b89e4f14cc959738ff`; **no se ha demostrado coincidencia con el certificado de una APK previamente instalada**.
- ZIP con APK, certificado, hashes y guía: https://github.com/jcarlospm05/ConduceMula/actions/runs/42795188150/artifacts/13754510325 (artefacto GitHub Actions, retención de 30 días).
- El ZIP y la APK descargados se verificaron por integridad con los checksums incluidos. La compilación de depuración usa una clave temporal de GitHub Actions.

**Pendiente antes de marcar la etapa como TERMINADA:** realizar y registrar los casos de la matriz Android/WhatsApp en un dispositivo físico; determinar compatibilidad de certificado con la instalación anterior y validar respaldo/actualización sin perder datos; configurar firma de producción estable y ejecutar el flujo manual `.github/workflows/muleagent-signed-release.yml`. Ese workflow requiere secretos GitHub protegidos y disponibilidad de ejecución en la rama predeterminada. El APK candidato NO debe distribuirse como actualización de producción.


## Incidencias reportadas en Android real — 10 de noviembre de 2026

**La APK debug 1.2.0+7 NO supera la aceptación de campo:** el usuario confirmó que el botón de WhatsApp entregó solamente un texto y no los JPG ni el paquete cifrado `.mule`; también observó la fotografía del horómetro distorsionada en la ficha JPG. El estado verde de GitHub Actions anterior no detectaba estos casos.

### Corrección 6.2 en `feat/etapa6-validacion-apk`

1. **WhatsApp:** el envío anterior combinaba `image/jpeg` y `application/octet-stream` y agregaba `EXTRA_TEXT`. Android podía emitir una acción mixta `*/*`, que WhatsApp puede interpretar como texto y descartar adjuntos. El nuevo envío genera un manifiesto de JPG + `.mule` sin texto y utiliza un **canal nativo Android** con `Intent.ACTION_SEND_MULTIPLE`, tipo uniforme `application/octet-stream`, `EXTRA_STREAM`, `ClipData` y `FileProvider` con permisos temporales de lectura. Evita confiar en la inferencia MIME de `share_plus` (que puede basarse en la extensión pese a `XFile.mimeType`). Copia los bytes originales a caché privada con los mismos nombres y no modifica los originales. Es una mitigación técnica, no una garantía de comportamiento de WhatsApp; requiere prueba física de envío completo. Las imágenes se enviarán como *documentos JPG*, no como fotos comprimidas de galería.
2. **Foto deformada:** `ui.instantiateImageCodec` recibía simultáneamente `targetWidth: 1060` y `targetHeight: 610`, lo que forzaba una relación de aspecto incorrecta *antes* del `BoxFit.contain`. Ahora decodifica con un solo límite dimensional y dibuja dentro de la ficha manteniendo proporciones, sin recortar ni alterar los originales.
3. **Pruebas de regresión:** comprobar que el descriptor de compartir incluye N fichas JPG + un archivo `.mule`, nombres legibles y ausencia de `EXTRA_TEXT`, y comprobar el canal nativo completo con Android; renderizar fotos horizontal y vertical y verificar que queda margen donde corresponde (sin deformación).
4. **Versión:** candidata **1.2.1+8**; el código Android, test CI de identidad y workflow de release quedan alineados. **No confundir con la APK anterior 1.2.0+7**. Generar nuevo ZIP/hash desde la ejecución nueva.

### Restricciones de integridad y aceptación

- Las fichas JPG ya emitidas en una revisión cerrada son **inmutables** y están vinculadas a hashes del respaldo. No reescribirlas silenciosamente al actualizar: crear una nueva revisión de la jornada para generar una ficha corregida, conservando los originales y el histórico.
- La prueba de Android debe verificar con el destinatario el **número exacto y los nombres** de adjuntos, la posibilidad de descargar y abrir `.mule`, y la orientación visual de al menos una foto vertical y otra horizontal. Probar nuevo cierre y reenvío desde historial.
- Si WhatsApp sigue rechazando lotes documentales con JPG y `.mule`, registrar evidencia y diseñar el envío alternativo por pasos JPG y `.mule`, sin declarar éxito ni fusionar como final. **No está validado ni implementado ese fallback.**
- La firma debug de una nueva ejecución de Actions puede variar; versión mayor no implica capacidad de actualizar sobre una instalación con certificado diferente. Respaldar antes y comprobar firma para cualquier migración.
- La etapa 6 sigue **EN DESARROLLO** hasta contar con CI, APK candidata 1.2.1+8 y prueba física favorable. La APK 1.2.0+7 queda invalidada como candidata aprobada de campo.
