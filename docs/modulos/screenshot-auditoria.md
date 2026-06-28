# Screenshot - Auditoria Y Plan

## Estado actual

El modulo ya cubre una v0:

- Requiere `Screen Recording`.
- Registra hotkey fija `Command + Shift + 4`.
- Captura pantalla completa.
- Abre preview en una ventana.
- Permite copiar o guardar PNG en `~/Downloads/Screenshots`.

## Hallazgos

### P0 - La hotkey choca con macOS

`Command + Shift + 4` es el atajo nativo de captura por zona en macOS. Usarlo
desde DropThings puede confundir al usuario y puede no registrarse si el
sistema lo consume primero.

Plan:

- Elegir un default menos conflictivo, por ejemplo `Option + Command + 4`.
- Hacer hotkey configurable.
- Si falla el registro, mostrar estado `degraded` con mensaje claro.

### P0 - Screen Recording, no Accessibility

Al igual que Color Picker, Screenshot necesita Screen Recording para capturar
otras apps. Dar Accessibility no alcanza.

Plan:

- Alinear copy de permisos con el uso real.
- Agregar troubleshooting especifico en el modulo.

### P0 - Guardado no usa `saveFolderBookmark`

`ScreenshotSettings` tiene `saveFolderBookmark`, pero `ScreenshotWriter`
siempre resuelve `~/Downloads/Screenshots`.

Plan:

- Agregar selector de carpeta.
- Guardar security-scoped bookmark si la app esta sandboxed.
- Usar fallback Downloads/Screenshots si el bookmark falla.

Criterio de aceptacion:

- Elegir carpeta, relanzar app y guardar vuelve a usar esa carpeta.

### P1 - Captura por zona

Esta es la evolucion natural antes del editor.

Plan:

- Reutilizar una variante del overlay del Color Picker.
- Drag para seleccionar rectangulo.
- ESC cancela.
- Enter confirma si hay seleccion.
- Mostrar dimensiones mientras se arrastra.
- Capturar solo el rect usando `ScreenCapture.captureScreen(rect:)`.

Criterio de aceptacion:

- El usuario puede arrastrar un area, confirmar y copiar/guardar solo esa
  region.

### P1 - Captura por pantalla y multi-monitor

La v0 no define bien si captura main display, union de pantallas o pantalla
activa.

Plan:

- Definir modos: pantalla activa, todas las pantallas, region.
- Documentar la decision en manual checks.
- Asegurar que la imagen no recorte displays secundarios sin avisar.

### P2 - Editor de anotaciones

La parte compleja conviene hacerla despues de region capture.

Herramientas iniciales:

- Flecha.
- Rectangulo.
- Texto.
- Lapiz/freehand.
- Resaltador.
- Pixelar/blur para ocultar informacion sensible.
- Selector de color y grosor.
- Undo/redo.

Arquitectura sugerida:

- `ScreenshotEditorModel`: imagen base + lista de anotaciones.
- `AnnotationShape`: enum codificable para rect, arrow, text, freehand.
- `ScreenshotRenderer`: convierte imagen base + anotaciones en PNG final.
- UI SwiftUI/AppKit separada del renderer para testear sin ventana real.

Criterio de aceptacion:

- Copiar/guardar incluye anotaciones horneadas en la imagen final.
- Undo/redo no degrada la imagen base.

### P2 - Flujo de salida

Mejoras futuras:

- Copiar automaticamente despues de capturar.
- Guardar automaticamente con nombre configurable.
- Abrir en Preview.
- Reveal in Finder.
- Formatos PNG/JPEG/WebP si hay razon real.

## Tests sugeridos

- Unit tests de settings y carpeta destino.
- Unit tests del renderer de anotaciones con imagen fixture pequena.
- Manual checks: permisos, pantalla completa, region, multi-monitor,
  cancelar con ESC, copiar/guardar.

