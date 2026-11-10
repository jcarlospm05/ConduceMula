# Etapa 6 — Validación final y APK única

**Estado: EN DESARROLLO — compilación candidata y validaciones finales.**
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
