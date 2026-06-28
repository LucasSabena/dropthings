# Auditoria Global De Modulos

Fecha: 2026-06-28

Alcance revisado:

- `FileShelf`
- `ScrollControl`
- `MenuBarCleaner`
- `KeepAwake`
- `ColorPicker`
- `Screenshot`
- Infraestructura compartida: permisos, hotkeys, icons, screen capture,
  menu bar, event taps y settings.

Resultado de verificacion:

- `swift test` pasa: 74 tests, 0 failures.
- Hay cambios locales no commiteados en docs; esta auditoria se agrego como
  archivo nuevo para no pisar trabajo existente.

## Hallazgos P0

### Color Picker: coordenadas multi-monitor todavia pueden samplear mal

Referencias:

- `Sources/DropThingsModules/ColorPicker/ColorPickerOverlayWindow.swift:23`
- `Sources/DropThingsModules/ColorPicker/ColorPickerOverlayWindow.swift:38`
- `Sources/DropThingsModules/ColorPicker/ColorPickerOverlayWindow.swift:103`
- `Sources/DropThingsModules/ColorPicker/ColorPickerModule.swift:197`

Problema:

El overlay ahora usa la union de todos los `NSScreen.frame`, lo cual es el
camino correcto. Pero el content view se asigna con `view.frame = unionFrame`
y el click se transforma como si el origen del capture/image fuese `(0, 0)`.
En setups con pantallas a la izquierda, arriba o con distinto scale, el punto
local puede no mapear al pixel real dentro del `CGImage`.

Impacto:

El usuario puede clickear un color y recibir otro, justo en el modulo donde
la precision importa mas.

Accion:

- Extraer un `ScreenCoordinateMapper` testeable.
- Guardar junto al screenshot el rect exacto capturado y el backing scale por
  pantalla.
- Convertir desde screen point real usando `window.convertPoint(fromScreen:)`
  y no `convert(_:from: nil)` para `NSEvent.mouseLocation`.
- Agregar tests de conversion para:
  - monitor principal en `(0,0)`;
  - monitor secundario con `minX < 0`;
  - monitor arriba con `minY > 0`;
  - retina/non-retina mixto si se decide soportar.

### Keep Awake: cambiar el modo mientras esta activo no reemplaza la assertion

Referencias:

- `Sources/DropThingsModules/KeepAwake/KeepAwakeModule.swift:50`
- `Sources/DropThingsModules/KeepAwake/KeepAwakeModule.swift:70`
- `Sources/DropThingsPlatform/Adapters/KeepAwakeAssertion.swift:37`

Problema:

`KeepAwakeAssertion.acquire(reason:)` devuelve `false` si ya hay una assertion
activa con otra razon, pero `KeepAwakeModule.applyState(true)` ignora ese
valor y marca `isKeepingAwake = true`. El UI queda diciendo que cambio a
`displaySleep` o `systemSleep`, pero la assertion real puede seguir siendo la
anterior.

Impacto:

El usuario cree que cambio el comportamiento de energia y no cambio.

Accion:

- Agregar `replace(reason:)` en `KeepAwakeAssertion`, o hacer que
  `setPreferredReason` libere y vuelva a adquirir si `isKeepingAwake`.
- Test unitario con fake assertion:
  - activar `systemSleep`;
  - cambiar a `displaySleep`;
  - verificar release + acquire nuevo.

### Screenshot: security-scoped resource se abre y no se cierra

Referencias:

- `Sources/DropThingsModules/Screenshot/ScreenshotModule.swift:116`
- `Sources/DropThingsModules/Screenshot/ScreenshotModule.swift:125`

Problema:

`resolveSaveFolder()` llama `startAccessingSecurityScopedResource()` y
devuelve el URL, pero no hay `stopAccessingSecurityScopedResource()`.

Impacto:

En builds sandboxed o futuros, puede filtrar accesos de seguridad y volver
impredecible el guardado luego de muchas capturas.

Accion:

- Cambiar el flujo a:
  - resolver URL + flag `didStartAccessing`;
  - guardar;
  - `defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }`.
- O crear un adapter `SecurityScopedURLAccess` en `Platform`.

## Hallazgos P1

### Scroll Control: la UI promete hotkey pero el modulo no la registra

Referencias:

- `Sources/DropThingsModules/ScrollControl/ScrollControlView.swift:15`
- `Sources/DropThingsModules/ScrollControl/ScrollControlModule.swift:108`

Problema:

La vista muestra `ShortcutRecorder(title: "Pause / resume")` y persiste la
hotkey en settings, pero `ScrollControlModule` no crea un `GlobalHotkey` ni
implementa pause/resume. Es una preferencia que parece real pero no actua.

Impacto:

Confusion directa: el usuario graba un shortcut, lo presiona y no pasa nada.

Accion:

- O retirar temporalmente el recorder de Scroll Control.
- O implementar `registerHotkey()` como en File Shelf/Color Picker/Screenshot,
  con una accion clara: pausar event tap sin apagar el modulo, o toggle
  enabled via `ModuleRegistry`.

### Menu Bar Cleaner: no verifica si ocultar/restaurar realmente funciono

Referencias:

- `Sources/DropThingsPlatform/Adapters/MenuBarController.swift:75`
- `Sources/DropThingsPlatform/Adapters/MenuBarController.swift:91`
- `Sources/DropThingsModules/MenuBarCleaner/MenuBarCleanerModule.swift:104`

Problema:

`applyHidden` descarta el resultado de `setVisible`. Si macOS o una app no
permite cambiar `AXVisible`, el UI puede decir que un item esta oculto aunque
la operacion haya fallado.

Impacto:

El modulo mas sensible a versiones de macOS queda sin feedback cuando falla.

Accion:

- Hacer que `applyHidden` devuelva un resumen:
  - applied ids;
  - failed ids;
  - unsupported ids.
- Mostrar `.degraded` o `lastRefreshError` cuando haya fallos.
- Guardar una compatibility note por macOS/app.

### Menu Bar Cleaner: instalar status items no es idempotente

Referencias:

- `Sources/DropThingsModules/MenuBarCleaner/MenuBarCleanerModule.swift:47`
- `Sources/DropThingsModules/MenuBarCleaner/MenuBarCleanerModule.swift:72`

Problema:

`start()` siempre llama `installStatusItems()`. Si el registro o UI dispara
`start()` dos veces sin `stop()`, se pueden crear status items duplicados.

Impacto:

Iconos duplicados en la barra y comportamiento de reveal ambiguo.

Accion:

- En `installStatusItems`, retornar si `separator` o `revealButton` ya existen.
- En `start()`, si `state == .running`, hacer no-op o refresh controlado.

### File Shelf: shake-to-show es caro y ruidoso para estar prendido por default

Referencias:

- `Sources/DropThingsModules/FileShelf/FileShelfSettings.swift:20`
- `Sources/DropThingsModules/FileShelf/FileShelfModule.swift:101`
- `Sources/DropThingsModules/FileShelf/FileShelfModule.swift:126`

Problema:

`shakeToShow` default es `true`. Eso activa un monitor de mouse a 60 Hz y
loguea heartbeat cada 120 muestras. Sirve para debug, pero como default de
producto puede gastar energia y llenar Console/Diagnostics.

Impacto:

Una utilidad de menu bar deberia sentirse liviana. El polling continuo puede
ser molesto en laptops.

Accion:

- Default `shakeToShow = false`.
- Reducir logs a debug-only o eliminar heartbeat.
- Activar shake solo si el usuario lo habilita explicitamente.
- Considerar trigger por drag near edge antes que polling global continuo.

### File Shelf: persistencia de pins no esta lista para sandbox

Referencia:

- `Sources/DropThingsModules/FileShelf/ShelfPersistence.swift`

Problema:

Los items pineados guardan URLs/paths en JSON. El comentario aclara que esta
bien para app no sandboxed, pero si DropThings apunta a distribucion sandboxed
habra que migrar a security-scoped bookmarks.

Impacto:

Pins persistentes pueden dejar de abrir/revelar archivos despues de relanzar
en un build sandboxed.

Accion:

- Definir decision de distribucion.
- Si sandboxed: guardar bookmark por file/folder item.
- Agregar migration de JSON path -> bookmark.

### Core: iconos genericos para nuevos modulos

Referencia:

- `Sources/DropThingsCore/DropThingsModule.swift:34`

Problema:

`iconName` solo cubre Scroll, File Shelf y Menu Bar Cleaner. Keep Awake,
Color Picker y Screenshot caen en `square.stack.3d.up`.

Impacto:

La lista de modulos pierde escaneabilidad visual.

Accion:

- Keep Awake: `moon.zzz` o `power`.
- Color Picker: `eyedropper`.
- Screenshot: `camera.viewfinder` o `rectangle.dashed`.

### Core: razon global de Screen Recording esta desactualizada

Referencia:

- `Sources/DropThingsCore/SystemPermission.swift:30`

Problema:

La razon dice "Required only to detect menu bar items visually", pero ahora
Color Picker y Screenshot tambien usan Screen Recording.

Impacto:

Refuerza la confusion de permisos: el usuario no entiende por que Screenshot
o Color Picker piden un permiso descrito como menu bar.

Accion:

- Cambiar razon global a algo mas general.
- Mejor: permitir `DropThingsModule` proveer reason especifica por permiso.

## Mejoras por modulo

### File Shelf

Siguiente slice recomendado:

- Hacer shake-to-show opt-in y silencioso.
- Agregar drag near screen edge como alternativa mas natural.
- Mostrar errores de reveal/copy si el archivo ya no existe.
- Diferenciar URL web vs texto plano en UI.
- Soportar imagenes del pasteboard como items temporales.
- Agregar security-scoped bookmarks si se decide sandbox.

Tests:

- Settings default de `shakeToShow`.
- Ingest de duplicados dentro del mismo drop. Hoy `existing` se calcula una
  vez antes del loop; conviene cubrir que dos items iguales en el mismo
  pasteboard no entren duplicados.

### Scroll Control

Siguiente slice recomendado:

- Implementar o quitar hotkey pause/resume.
- Exponer estado de event tap timeout en UI (`EventTapClient.isTimedOut`).
- Agregar accion "Reinstall event tap".
- Ajustar copy para explicar que requiere Accessibility.
- Explorar perfiles por dispositivo real si el heuristico no alcanza.

Tests:

- Settings con hotkey round-trip.
- Pause/resume si se implementa.
- Event tap timeout simulado via adapter fake.

### Menu Bar Cleaner

Siguiente slice recomendado:

- Hacer `applyHidden` observable y reportar fallos.
- Evitar status items duplicados.
- Agregar perfil "presentation mode".
- Agregar reorder como fase separada:
  - primero lista manual visible/hidden;
  - luego orden deseado dentro de visible;
  - despues intento best-effort de mover iconos via Accessibility.
- Documentar compatibilidad por macOS/app.

Importante:

Mover iconos de la menu bar no debe prometerse como 100% garantizado. Debe
ser "best effort", con reset y rollback.

### Keep Awake

Siguiente slice recomendado:

- Corregir replace de assertion al cambiar reason activo.
- Agregar duracion: 15m, 30m, 1h, indefinido.
- Mostrar tiempo restante.
- Agregar accion rapida desde menu bar.
- Agregar manual check para cambio de reason activo con `pmset -g assertions`.

### Color Picker

Siguiente slice recomendado:

- Corregir mapeo de coordenadas multi-monitor.
- Agregar lupa/zoom antes de cualquier feature secundaria.
- Mostrar pixel central y valor bajo cursor.
- Formatos de copia: HEX, RGB, HSL, CSS, SwiftUI.
- Favoritos/pins en historial.
- Colores similares por HSL.
- Integracion con Clipboard History como item enriquecido.

Tests:

- `ScreenCoordinateMapper`.
- RGB -> HSL.
- Paleta derivada deterministica.
- Hotkey conflict state.

### Screenshot

Siguiente slice recomendado:

- Balancear security-scoped access.
- Agregar `lastError` visible para capture/save/copy.
- Captura por region con overlay propio, reutilizando aprendizajes del Color
  Picker pero no acoplando modulos.
- Captura por ventana.
- Editor ligero: rectangulo, flecha, texto, freehand, blur/pixelate.
- Guardado/copiar automatico como setting.

Tests:

- Save folder bookmark flow con adapter fake.
- Renderer de anotaciones con imagen fixture chica.

## Modulos nuevos recomendados

Orden recomendado:

1. Color Picker Pro antes de todo: si el picker no es preciso, se siente roto.
2. Clipboard History MVP: alto valor diario, sin permisos para copiar/recordar.
3. Menu Bar Cleaner estabilidad + reorder best-effort.
4. Screenshot region capture.
5. Command Palette para accionar modulos.
6. Window Snapper estilo Rectangle.
7. Text Tools.
8. Focus / Presentation Mode como workflow que coordina modulos existentes.

### Clipboard History

MVP:

- Hotkey editable.
- Historial texto/URL/imagen/color.
- Busqueda.
- Pins.
- Pausa/incognito.
- Borrado por item y limpiar todo.

Privacidad:

- Excluir apps sensibles.
- No persistir tokens o strings sospechosos por defecto.
- Persistencia local con permisos de archivo restrictivos.

### Window Snapper

Inspiracion:

- Rectangle como base: halves, quarters, thirds, center, maximize, restore.
- Snap areas al arrastrar a bordes/esquinas.
- Repetir shortcut para ciclar tamanos.

Permisos:

- Accessibility.

Primer slice:

- Ventana activa solamente.
- Left/right/top/bottom halves.
- Quarters.
- Maximize/center.
- Restore.
- Mover entre monitores.

## Recomendacion de ejecucion

No abrir todo a la vez. El orden mas sano:

1. Fix P0: Color Picker coords, Keep Awake replace, Screenshot scoped access.
2. Limpiar P1 pequenos: Scroll hotkey real/oculta, iconos, reason de permisos.
3. Color Picker Pro zoom.
4. Clipboard History MVP.
5. Menu Bar Cleaner reportes de fallo + base para reorder.

