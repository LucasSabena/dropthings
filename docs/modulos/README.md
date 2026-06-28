# Auditoria De Modulos Nuevos

Fecha: 2026-06-28

Este directorio baja a tierra las mejoras para los modulos nuevos que ya
existen en codigo:

- `KeepAwake`: mantener la Mac despierta con una assertion de energia.
- `ColorPicker`: seleccionar un pixel de la pantalla, copiar el color y
  conservar historial.
- `Screenshot`: capturar pantalla completa hoy, y evolucionar a captura
  por zona con anotaciones.

## Lectura rapida

Prioridad 0:

- Separar con claridad `Accessibility` de `Screen Recording`. Color Picker y
  Screenshot no funcionan solo con Accessibility; necesitan Screen Recording.
- Mejorar los mensajes de permisos para explicar el uso real por modulo.
- Hacer que los estados de error sean visibles en UI, no solo en Console.app.
- Corregir la historia de multi-monitor: los manual checks prometen mas de
  lo que el codigo actual garantiza.

Prioridad 1:

- Agregar hotkeys configurables y detectar conflictos.
- Guardar preferencias de Keep Awake.
- Agregar preview/magnifier, formatos de copia y similares en Color Picker.
- Agregar seleccion por region en Screenshot antes de anotar imagenes.

Prioridad 2:

- Editor de anotaciones para Screenshot.
- Paletas y sugerencias por tono en Color Picker.
- Presets/scheduler en Keep Awake.

## Archivos

- `keep-awake-auditoria.md`: mejoras para energia, persistencia y UX.
- `color-picker-auditoria.md`: permisos, sampling, historial, formatos y
  colores similares.
- `screenshot-auditoria.md`: region capture, editor, guardado y permisos.
- `permisos-diagnostico-auditoria.md`: causa probable de "di permiso y no
  funciona" y mejoras transversales.
- `backlog-modulos-futuros.md`: modulos candidatos y orden sugerido de
  construccion.

## Criterio general

Cada modulo debe mantener la forma de DropThings:

- El modulo contiene la experiencia y settings.
- `Platform` envuelve APIs fragiles de macOS.
- `Core` decide registro, permisos, estado y diagnostico.
- `DesignSystem` provee tokens y componentes compartidos.
- Ningun modulo depende directamente de otro.
