# Auditoria De Modulos Nuevos

Fecha: 2026-06-28

Este directorio baja a tierra las mejoras para los modulos nuevos que ya
existen en codigo:

- `KeepAwake`: mantener la Mac despierta con una assertion de energia.
- `ColorPicker`: seleccionar un color con el sampler nativo de macOS, copiarlo y
  conservar historial.

## Lectura rapida

Prioridad 0:

- Separar con claridad `Accessibility` de permisos futuros como
  `Screen Recording`. Los modulos activos no deben pedir permisos que no usan.
- Mejorar los mensajes de permisos para explicar el uso real por modulo.
- Hacer que los estados de error sean visibles en UI, no solo en Console.app.
- Corregir manual checks cuando prometen mas de lo que el codigo actual
  garantiza.

Prioridad 1:

- Agregar hotkeys configurables y detectar conflictos.
- Guardar preferencias de Keep Awake.
- Agregar preview/magnifier, formatos de copia y similares en Color Picker.

Prioridad 2:

- Replantear Screenshot Studio como modulo futuro con region capture y editor.
- Paletas y sugerencias por tono en Color Picker.
- Presets/scheduler en Keep Awake.

## Archivos

- `keep-awake-auditoria.md`: mejoras para energia, persistencia y UX.
- `color-picker-auditoria.md`: permisos, sampling, historial, formatos y
  colores similares.
- `permisos-diagnostico-auditoria.md`: causa probable de "di permiso y no
  funciona" y mejoras transversales.
- `backlog-modulos-futuros.md`: modulos candidatos y orden sugerido de
  construccion.
- `auditoria-global-modulos-2026-06-28.md`: revision global de todos los
  modulos actuales con hallazgos P0/P1/P2 y proximos slices.

## Criterio general

Cada modulo debe mantener la forma de DropThings:

- El modulo contiene la experiencia y settings.
- `Platform` envuelve APIs fragiles de macOS.
- `Core` decide registro, permisos, estado y diagnostico.
- `DesignSystem` provee tokens y componentes compartidos.
- Ningun modulo depende directamente de otro.
