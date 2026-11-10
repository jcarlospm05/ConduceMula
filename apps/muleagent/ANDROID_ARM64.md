# MuleAgent ConduceMula — entrega ARM64

## Release optimizada: 1.2.2 (25.9 MB)

La APK directa se construye en GitHub Actions mediante `flutter build apk --release --split-per-abi --build-name=1.2.2 --build-number=9 --obfuscate --split-debug-info=build/symbols`.

- **Tamaño:** 25,945,455 bytes (límite verificado: 90,000,000 bytes).
- **Identidad Android:** `com.muleagent.operador`, `versionName 1.2.2`, `versionCode 2009` para ARM64.
- **Verificación:** `apksigner` firma válida, `aapt` sin modo debug, comprobación ABI `arm64-v8a`, SHA-256 y ausencia de otras bibliotecas ABI.
- **SHA-256:** `36b59f9fd6e98af8302ff61284a7a22c73ab5fd4194ebdaf8ea529add7e521ec`.
- **Descarga directa:** https://github.com/jcarlospm05/ConduceMula/releases/download/conducemula-v1.2.2-arm64-release-candidate/MuleAgent-ConduceMula-1.2.2-arm64-release.apk

La APK debug de 1.2.1 medía 101 MB porque contenía bibliotecas, runtime y kernel sin la optimización release. No se eliminaron las funciones de la app para alcanzar 25.9 MB. Se corrigieron los dos logos erróneamente codificados como JPEG con extensión PNG, manteniendo sus píxeles idénticos.

**Estado de firma y despliegue:** la compilación 1.2.2 está firmada con **clave temporal de pruebas** al no haberse configurado una firma de producción con copia de seguridad. No distribuir como versión final de producción ni sustituir una app con datos sin respaldo y verificación de certificado. Falta aceptación física de JPG + .mule en WhatsApp, regeneración de fotos y restauración de datos.

La APK ARM64 debug 1.2.1 permanece como referencia de prueba anterior, pero NO se recomienda para nuevas validaciones.
