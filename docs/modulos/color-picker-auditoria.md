# Color Picker - Auditoria Y Plan

## Estado actual

El modulo ya existe y cubre una primera version:

- Requiere `Screen Recording`.
- Registra hotkey fija `Option + Command + C`.
- Captura pantalla con `ScreenCapture`.
- Muestra overlay con crosshair.
- Al clickear, samplea pixel, copia HEX al portapapeles y guarda historial.

## Hallazgos

### P0 - Permiso confundible: Accessibility no alcanza

Color Picker no usa Accessibility. Para ver pixeles de otras apps necesita
Screen Recording. Si el usuario solo habilita Accessibility, el modulo debe
seguir bloqueado.

Plan:

- Ajustar copy de permisos para este modulo: "Necesario para leer pixeles de
  la pantalla".
- En el estado `needsPermission`, mostrar cual falta y por que.
- Agregar una nota en diagnostico cuando Screen Recording esta no otorgado.

Criterio de aceptacion:

- La pantalla del modulo deja claro que Accessibility no resuelve Color
  Picker.

### P0 - Multi-monitor no esta resuelto

`ColorPickerOverlayWindow` usa `NSScreen.main` para el panel. Los checks
manuales actuales dicen que debe funcionar en multiples pantallas, pero el
codigo solo cubre la principal de forma confiable.

Plan:

- Crear un overlay por `NSScreen`, o un panel que cubra el frame union de
  todas las pantallas.
- Mantener un mapeo explicito entre coordenadas AppKit y coordenadas de
  `CGImage`.
- Agregar tests puros para conversion de coordenadas.

Criterio de aceptacion:

- Click en monitor primario y secundario copia el color correcto.
- El overlay aparece en todos los monitores activos.

### P0 - Errores solo van a logs

Si falla la captura o el hotkey, el usuario no ve recuperacion clara.

Plan:

- Guardar `lastError` o mover el modulo a `failed/degraded` segun gravedad.
- Mostrar inline alert: captura fallida, permiso faltante, hotkey ocupado.
- Incluir accion "Refresh permissions".

### P1 - Hotkey configurable y conflictos

La hotkey fija puede chocar con apps de diseno o shortcuts del sistema.

Plan:

- Extraer `GlobalHotkey.Definition` a settings codificable.
- Crear UI nativa de grabar shortcut.
- Detectar `RegisterEventHotKey` fallido y marcar estado degradado.

### P1 - Magnifier y preview antes de click

Para sentirse como PowerToys, el picker necesita lupa alrededor del cursor.

Plan:

- Capturar una region pequena alrededor del cursor o recortar la imagen
  capturada.
- Mostrar zoom 8x-12x, grid de pixel central y color actual.
- Actualizar preview con mouse move, sin copiar hasta click.

Criterio de aceptacion:

- El usuario ve el pixel exacto antes de confirmar.

### P1 - Formatos de copia

Hoy copia siempre HEX. Usuarios de UI/code suelen alternar formatos.

Plan:

- Agregar formato preferido: HEX, RGB, HSL, SwiftUI `Color`, CSS.
- Agregar menu contextual por historial para copiar en otro formato.
- Guardar ultimo formato elegido.

### P1 - Historial mas util

El historial ya existe, pero puede crecer hacia una mini paleta.

Plan:

- Agrupar por fecha/sesion de trabajo.
- Agregar busqueda por HEX/RGB.
- Permitir pin/favorite.
- Exportar paleta como JSON/CSS variables.

### P2 - Colores similares

La idea de "colores similares por tono" conviene hacerla con logica pura y
testeable.

Plan:

- Agregar conversion RGB -> HSL.
- Generar variaciones: mas claro, mas oscuro, saturado, desaturado,
  complementario, analogos.
- Mostrar la sugerencia junto al color seleccionado, no mezclada con el
  historial real.

Criterio de aceptacion:

- Para un color base, la lista de similares es deterministica y testeada.

## Tests sugeridos

- Unit tests de `PickedColor` para HEX/RGB/HSL.
- Unit tests de conversion de coordenadas multi-display.
- Unit tests de generacion de colores similares.
- Manual checks con Screen Recording otorgado, revocado y reseteado.

