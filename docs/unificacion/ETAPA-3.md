# Etapa 3 — INTERFAZ_MULEAGENT_V1 (ConduceMula)

Estado: **en ejecución; primer checkpoint implementado en la rama feat/interfaz-muleagent-v1**.
La base es la etapa 2 de `refactor/mule-unificada`, ya transferida desde MuleAgent.
MuleAgent original no debe recibir modificaciones.

## Referencia inalterable

- Variable: **INTERFAZ_MULEAGENT_V1**; nombre: MuleAgent Flat.
- Documento completo: https://docs.google.com/document/d/18f63v6x8-CldXL8Rqm2jgOH3Qci13ewg9_ttPO35vwQ/edit
- Imagen aprobada copiada: https://drive.google.com/file/d/1sRh6ZPff8vg2xSntXsA1eI6ELH7Z3dlK/view
- Paleta y medidas: `apps/operador/lib/design/mule_tokens.dart`.

## Primer checkpoint de código

- `mule_theme.dart`: temas claro y oscuro, superficies sólidas, Roboto y jerarquía de botones.
- `MuleAgentApp`: selección de tema mediante ThemeMode.
- `UnifiedShell`: guarda/restaura `mule_theme_v1` dentro de la configuración local; el perfil sigue almacenado de forma segura, independiente de ese ajuste. No modifica claves ni migraciones existentes.
- **LOGO_MULEAGENT_V1**: PNG original aprobado, copiado sin alteraciones a `apps/operador/assets/LOGO_MULEAGENT_V1.png` y al recurso del lanzador Android. El widget `mule_truck_logo.dart` muestra directamente el PNG, sin recrearlo como vector.
- `OperatorScreen` en modo Mule: encabezado compacto, logo y control luna/sol; acciones de entrada y salida jerarquizadas; salida naranja; aviso de proceso abierto, botón Continuar y punto rojo sin números; opciones secundarias como filas planas.
- Hora/minutos: campos independientes numéricos, foco y normalización `HH:mm` en el formato de datos existente.
- Botón Siguiente fijado fuera del área desplazable de captura, para permanecer disponible cuando se abre el teclado.
- Miniatura visible de la imagen original del horómetro y ampliación al tocar; no reemplaza ni recorta el original.
- Se conservan los flujos, las rutas de archivo, las revisiones y los permisos heredados. No se introduce cambio de esquema.

## Verificación y pendientes

- Se incorporaron pruebas de selección/persistencia de tema, salida naranja, continuación de una etapa abierta y campos separados de hora/minutos.
- El workflow `mule-unificada.yml` se habilitó para la nueva rama, con análisis, regresiones y compilación Android. **No afirmar que pasó hasta consultar los resultados del run.**
- Comprobar visualmente claro/oscuro, textos ampliados, miniaturas y teclado en dispositivos pequeños Android reales.
- Logo original: integridad del blob verificada en ambos destinos del repositorio. Comprobar tamaño efectivo en el encabezado y en el lanzador sobre Android físico.
- Revisar todos los recorridos restantes para mantener la misma jerarquía visual.
- **Las etapas 4 y 5 están pendientes:** no cambiar todavía contrato .mule, JPG del conduce, flujo PDF ni consolidación administrativa.

## Criterio de cierre

Análisis Flutter sin errores, regresiones aprobadas, prueba de UI/teclado en teléfono, y comparación visual con la referencia. Al cerrar, registrar el commit y las incidencias. Una captura satisfactoria no equivale a APK final.
