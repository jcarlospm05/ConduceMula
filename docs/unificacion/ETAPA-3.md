# Etapa 3 — INTERFAZ_MULEAGENT_V1 (ConduceMula)

Estado: **COMPLETADA el 9 de noviembre de 2026 e integrada en `refactor/mule-unificada`**.
La base es la etapa 2 de `refactor/mule-unificada`, ya transferida desde MuleAgent.
MuleAgent original no debe recibir modificaciones.

## Referencia inalterable

- Variable: **INTERFAZ_MULEAGENT_V1**; nombre: MuleAgent Flat.
- Documento completo: https://docs.google.com/document/d/18f63v6x8-CldXL8Rqm2jgOH3Qci13ewg9_ttPO35vwQ/edit
- Imagen aprobada copiada: https://drive.google.com/file/d/1sRh6ZPff8vg2xSntXsA1eI6ELH7Z3dlK/view
- Paleta y medidas: `apps/operador/lib/design/mule_tokens.dart`.

## Implementación cerrada

- `mule_theme.dart`: temas claro y oscuro, superficies sólidas, Roboto y jerarquía de botones.
- `MuleAgentApp`: selección de tema mediante ThemeMode.
- `UnifiedShell`: guarda/restaura `mule_theme_v1` dentro de la configuración local; el perfil sigue almacenado de forma segura, independiente de ese ajuste. No modifica claves ni migraciones existentes.
- **LOGO_MULEAGENT_V1**: PNG original aprobado, copiado sin alteraciones a `apps/operador/assets/LOGO_MULEAGENT_V1.png` y al recurso del lanzador Android. El widget `mule_truck_logo.dart` muestra directamente el PNG, sin recrearlo como vector.
- `OperatorScreen` en modo Mule: encabezado compacto, logo y control luna/sol; acciones de entrada y salida jerarquizadas; salida naranja; aviso de proceso abierto, botón Continuar y punto rojo sin números; opciones secundarias como filas planas.
- Hora/minutos: campos independientes numéricos, foco y normalización `HH:mm` en el formato de datos existente.
- Botón Siguiente fijado fuera del área desplazable de captura, para permanecer disponible cuando se abre el teclado.
- Miniatura visible de la imagen original del horómetro y ampliación al tocar; no reemplaza ni recorta el original.
- Se conservan los flujos, las rutas de archivo, las revisiones y los permisos heredados. No se introduce cambio de esquema.

## Verificación de cierre

- Repositorio de trabajo y destino: **jcarlospm05/ConduceMula**, exclusivamente.
- PR de integración: https://github.com/jcarlospm05/ConduceMula/pull/1
- Merge a la rama de desarrollo `refactor/mule-unificada`: `6bbce0265af992b6b5d741509d300d0b8c30b1b4`.
- GitHub Actions (MuleAgent modular): https://github.com/jcarlospm05/ConduceMula/actions/runs/42680728689 — **success**.
- Dart/Flutter Analyze de perfiles, datos, captura, receptor y app unificada: **sin incidencias**.
- **54 pruebas aprobadas**: 6 perfiles, 12 datos compartidos, 11 datos Administrador, 12 captura/archivos, 3 receptor, 10 app unificada. Incluye test nuevo de tema claro/oscuro y su persistencia, salida naranja, reanudación y captura HH:mm.
- Android: `flutter build apk --debug` completó correctamente para `apps/muleagent` (una sola aplicación unificada). La APK depuración no constituye entrega final ni APK firmada de producción.
- Identidad visual: el PNG original `LOGO_MULEAGENT_V1` tiene la misma huella Git `ba68768a96da18e5922b0d404f35069da29c243b` en Flutter y Android; no se redibujó.
- Se conservan esquemas y módulos de datos/cifrado/perfiles de las etapas 1–2, sin modificación.

## Pendientes trasladados a otras etapas

- **Etapa 4**: generar JPG por mula, envío conjunto JPG + .mule, eliminar PDF del recorrido de captura.
- **Etapa 5**: selección/exclusión de fichas e informes PDF administrativos.
- **Etapa 6**: pruebas en Android físico (texto ampliado, teclado, fotos, icono del lanzador y modo oscuro), conservación de datos al actualizar, firma y empaquetado ZIP final.

La etapa 3 se cierra por implementación, análisis, pruebas Flutter y compilación Android. No se declara efectuada la prueba física: forma parte de la etapa 6. El repositorio original MuleAgent permanece intacto.
