# MuleAgent ConduceMula · APK Android ARM64 de prueba

Esta compilación se produce desde el mismo código de MuleAgent unificado
(versión 1.2.1+8) con `flutter build apk --debug --target-platform=android-arm64`.

Motivo: la APK universal de depuración lleva tres arquitecturas y supera
el límite de 100 MiB para transferir archivos individuales mediante la
conexión de Google Drive. El APK ARM64 contiene solo librerías `arm64-v8a`
y se puede descargar e instalar directamente como archivo .apk en
teléfonos Android modernos de 64 bits.

## Comprobación

El workflow `mule-unificada.yml` verifica applicationId, versionCode,
versionName, la firma con `apksigner` y la presencia de arm64-v8a sin
librerías de 32 bits o x86_64. Publica el artefacto
`ConduceMula-Android-ARM64-APK-Directa` para entrega independiente.

**No es una APK final de producción.** Se mantiene firma de depuración.
La migración desde la APK previa exige comparar certificados y respaldar
los datos de SQLite antes de instalar. Falta prueba física WhatsApp de
adjuntos JPG y .mule y evidencia de foto con proporción correcta.
