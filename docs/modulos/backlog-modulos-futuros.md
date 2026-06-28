# Backlog De Modulos Futuros

Fecha: 2026-06-28
Actualizado: tras la tanda de File Shelf v1, Scroll Control, Menu Bar Cleaner
v1, Keep Awake v0, Color Picker v0, Screenshot v0 + las auditorias
transversales en `docs/modulos/`.

Objetivo: elegir proximos modulos para DropThings sin romper su forma:
utilidades pequenas, nativas, confiables, con permisos claros y modulos
aislados.

## Principio de seleccion

Un buen modulo para DropThings deberia cumplir al menos dos condiciones:

- Se usa muchas veces por dia.
- Ahorra clicks o cambio de contexto.
- Puede vivir como herramienta pequena, no como app enorme.
- Tiene permisos explicables.
- Puede fallar de forma clara y reversible.

## Estado actual al 2026-06-28

Modulos ya construidos y donde vive el codigo:

| Modulo | Estado | Permisos | Notas |
|---|---|---|---|
| File Shelf | v1 | ninguno | drop, drag-out, pin + persistencia JSON, hotkey editable, shake-to-show |
| Scroll Control | v0 | Accessibility | event tap por categoria de dispositivo, multiplier, hotkey editable opcional |
| Menu Bar Cleaner | v1 | Accessibility | AX enumeration + toggle por item, separator + reveal status item, auto-refresh via NSWorkspace |
| Keep Awake | v0 + audit fixes | ninguno | IOPMAssertion con preferencia persistida y toggle restore-on-launch |
| Color Picker | v0 + audit fixes | Screen Recording | overlay full-screen union multi-monitor, history persistido, hotkey editable |
| Screenshot | v0 + audit fixes | Screen Recording | captura full-screen, save folder via security-scoped bookmark, hotkey editable |

Modulo fantasma (`FakeModule`) borrado. Decision documentada en
`docs/decisions.md`.

## Infraestructura compartida disponible

Lo que ya existe en el repo y cualquier modulo nuevo puede reusar sin
tocar otros modulos:

### Platform

- `GlobalHotkey` — wrapper Carbon `RegisterEventHotKey` con cleanup.
  `GlobalHotkey.Definition` es Codable + tiene `displayString` ("⌥⌘C")
  y `hasModifier`. Defaults: `defaultShelfHotkey`, `defaultColorPickerHotkey`,
  `defaultScreenshotHotkey` con IDs fijos.
- `ScreenCapture` — `CGWindowListCreateImage` para captura de pantalla
  o region. v0 sin permisos requeridos para la captura, pero Screen
  Recording es necesario en produccion para contenido de otras apps.
- `PixelSampler` — lee bytes RGBA8 de un `CGImage` y devuelve `RGB`
  con `hex`, `rgbString`, `nsColor`. Usado por Color Picker; reusado
  por Screenshot cuando llegue el color picker del editor.
- `KeepAwakeAssertion` — wrapper `IOPMAssertion` con acquire/release
  idempotente y `Reason` (systemSleep, displaySleep).
- `EventTapClient` — `CGEventTap` con timeout recovery. Usado por Scroll
  Control; reusado por futuros modulos que necesiten inyectar o modificar
  input events.
- `MenuBarController` — enumera y toggle visibilidad de items del menu bar
  via `kAXVisibleAttribute`. Usado por Menu Bar Cleaner.
- `DropThingsStatusItem` — wrapper `NSStatusItem` con closure de click.
  Usado por Menu Bar Cleaner para el separator y el reveal button;
  reusado por futuros modulos que necesiten su propio status item.
- `MousePositionMonitor` — polea `NSEvent.mouseLocation` 60 Hz con handler
  MainActor. Usado por File Shelf para shake-to-show.

### DesignSystem

- `ShortcutRecorder` — vista SwiftUI que captura el siguiente `keyDown`
  via `NSEvent.addLocalMonitorForEvents`. Rechaza combinaciones sin
  modificador. ESC cancela. Devuelve `GlobalHotkey.Definition?`.
  Cero permisos. Cualquier modulo puede meterla en su settings.
- `SettingsSection`, `PermissionRow`, `ModuleRow`, `InlineAlert`,
  `ModuleStatusPill` — composicion consistente para paginas de modulo.
- Tokens: `DTColor`, `DTSpace`, `DTRadius`, `DTTypography`, `DTSize`.

### Core

- `PermissionCenter` con `Request Access` que dispara el prompt nativo de
  macOS via `AXIsProcessTrustedWithOptions` o `CGRequestScreenCaptureAccess`.
  El modulo no tiene que implementar el flujo de "pedir permiso" — llama
  `permissions.requestPermission(_:)` y se entera del resultado via `refresh()`.
- `SettingsStore` tipado con `SettingsKey`. Cualquier modulo guarda con
  `settingsStore.saveXxxSettings(...)`. Migracion = custom `init(from decoder:)`
  con `decodeIfPresent` por campo.
- `DiagnosticsStore` con buffer circular (500 entries) accesible via
  `DiagnosticsView` y via `DiagnosticsStore.recordAndLog`.
- `ModuleRegistry` con `setEnabled`, `refreshPermissionsAndRetry`, `bootEnabledModules`.

### App

- `OnboardingWindowController` se muestra la primera vez (clave
  `app.dropthings.onboarding.completed` en UserDefaults). Futuros modulos
  pueden agregarse al `OnboardingView` con una oracion y un icono SF Symbol.
- `SettingsImporter` + `SettingsWindowController` para importar/exportar
  el suite `app.dropthings` completo via `defaults`.
- `BundleInfo` + panel "App" en Diagnostics para troubleshooting de
  permisos (muestra `Bundle ID`, `Bundle path`, version, `AXIsProcessTrusted`).

## Lecciones aprendidas (aplican a todo modulo nuevo)

Estas vinieron de las auditorias en `docs/modulos/` y conviene releerlas
antes de empezar:

### Permisos

- **Accessibility y Screen Recording son permisos distintos.** El menu
  de System Settings los lista por separado. Si tu modulo necesita los
  dos, declaralos ambos en `requiredPermissions` y mostralos en dos filas
  del PermissionRow. Nunca pidas solo Accessibility si lo que necesitas es
  Screen Recording: el usuario concede Accessibility, ve "necesita permiso",
  y no entiende por que.

- **El prompt nativo se dispara con `AXIsProcessTrustedWithOptions` /
  `CGRequestScreenCaptureAccess`, no abriendo System Settings.** El
  boton "Request Access" debe llamar `permissions.requestPermission(_:)`.
  Abrir System Settings sin disparar el prompt deja al usuario con un grant
  que no se traduce en acceso real.

- **El grant de TCC esta atado al path absoluto del binario.** Si
  DropThings se reconstruye en otro path (CI, otra build, mover el `.app`),
  el grant anterior no aplica. BundleInfo expone el path real para que
  el usuario pueda compararlo con lo que ve en System Settings. Si
  mismatch, `tccutil reset <Permission> app.dropthings`.

- **Distincion `notDetermined` vs `denied` es opaca en macOS.** El
  PermissionBackend solo distingue tres: granted / notDetermined / unknown.
  El copy de UI debe decir "Not granted" en lugar de inventar un "Denied".

### Estado y errores visibles

- **El modulo debe tener un `lastError` published o terminar en
  `.degraded` / `.failed` cuando algo sale mal.** Logs en Console.app no
  alcanzan. El usuario mira la UI. Si el modulo no expone el error
  reciente, queda en silencio.

- **Failure modes que vimos y queremos que todo modulo nuevo cubra:**
  - Hotkey ya tomada por otra app → `.degraded` con la combinacion
    exacta y sugerencia de menu bar como fallback.
  - Permission denegada → `.needsPermission(missing: [...])` con accion
    directa a "Request Access" + "Open System Settings".
  - Captura/copia de archivo falla → `lastError` con mensaje legible
    (no `String(describing: error)`).

### Hotkeys

- **Toda hotkey va en Settings, editable, persistida.** No hardcodear.
  Default con `GlobalHotkey.defaultXxxHotkey`, override via ShortcutRecorder.
  Si `RegisterEventHotKey` falla, degradado + mensaje que nombra la
  combinacion y ofrece alternativa.

- **Una sola hotkey por modulo, registrada con id fijo.** Si en el futuro
  un modulo necesita multiples hotkeys (ej. screenshot full vs region),
  hay que definir `defaultXxxHotkey2` con un id nuevo.

### Settings

- **Codable + JSON desde el dia 1.** `SettingsStore` ya soporta el patron.
  No usar `integer(forKey:)` / `bool(forKey:)` por campo — eso bloquea
  migraciones. Con Codable, agregar un campo es un `decodeIfPresent` en
  `init(from decoder:)`.

- **Custom `init(from decoder:)` con `decodeIfPresent` para todo
  campo.** Asi un JSON viejo no rompe decode. El bug que ya tuvimos:
  `ScrollSettings` sin `init(from:)` rompia al agregar `hotkey` para
  usuarios que tenian settings persistidas de antes.

### Tests

- **Pure logic primero.** Cualquier modulo que tenga decision de "que
  hacer con este input" debe tener esa decision como funcion pura
  testeable. El adapter (CGEvent, AXUIElement, NSPasteboard) se testea
  por separado o se verifica manualmente.

- **Coverage minima esperada por modulo:**
  - Settings round-trip (load → save → load es identico).
  - Classifier/transformer pure logic (si tiene).
  - 1 test por cada `static func sanitized` (clamping, defaults).

### Coordinacion entre modulos

- **Modulos no se importan entre si.** Si Color Picker publica un evento
  "color picked" que Clipboard History quiere consumir, va por un
  servicio compartido en Core, no por importacion directa.
- **Estado compartido va en Core, no en AppServices.** Por ejemplo,
  "ultimo color copiado" deberia vivir en `Core` si Clipboard History y
  Color Picker necesitan leerlo. AppServices es composition root pero
  no storage compartido.

## Prioridad recomendada (revisada)

### 1. Clipboard History

Este deberia ser uno de los modulos centrales.

Problema:

- macOS tiene un clipboard unico y se pierde rapido lo copiado.
- Desarrolladores, diseno y trabajo diario necesitan recuperar texto,
  links, colores, imagenes y archivos recientes.

MVP:

- Hotkey global editable para abrir historial (usar `ShortcutRecorder`).
- Lista de items recientes.
- Buscar por texto.
- Click o Enter para pegar/copiar.
- Pin/favoritos.
- Borrar item individual y limpiar todo.
- Pausar captura.

Tipos iniciales:

- Texto plano.
- URLs.
- Imagenes.
- Colores copiados por Color Picker (enriquecer item con swatch + hex).
- Archivos como referencias, no duplicando contenido.

Permisos:

- Sin permisos para leer `NSPasteboard` y mantener historial en memoria.
- Para pegar automaticamente en la app activa puede necesitar Accessibility
  o simulacion de teclado. Mantenerlo opcional y detras de un toggle
  "paste into focused app".

Privacidad (no negociable):

- Lista negra de apps sensibles (1Password, Keychain Access, banking).
  Editable por el usuario en settings. El monitor no guarda items cuya
  app de origen este en la lista.
- Toggle "no guardar contrasenas": detectar tipos `NSPasteboard.PasteboardType`
  sospechosos o texto que matchee heuristica simple (mas de N caracteres
  sin espacios, parece token).
- Modo incognito temporal: pausa la captura por N minutos.
- Persistencia cifrada o local-only con `FileProtection.complete` no aplica
  en macOS, pero el archivo vive en `~/Library/Application Support/app.dropthings/`
  con permisos `0600`.

Arquitectura:

- `ClipboardModule` en `Modules`.
- `PasteboardMonitor` en `Platform` usando `NSPasteboard.changeCount` con
  polling cada 500 ms (la API no notifica, hay que polear).
- `ClipboardStore` con limite, pins y expiracion. Codable.
- Servicio compartido en `Core` para "ultimo color picked" — Clipboard
  History se suscribe y enriquece el item.

Manual checks a incluir desde el dia 1:

- Copiar texto desde TextEdit, pegar desde DropThings → texto correcto.
- Copiar imagen desde Preview → preview en historial.
- Copiar URL desde Safari → preview con hostname.
- Copiar color con Color Picker → swatch + hex en historial.
- Toggle de pausa → copiar 5 cosas, no se agregan al historial.
- Lista negra → copiar desde 1Password → no se guarda.

Auditoria previa recomendada: `docs/modulos/clipboard-history-auditoria.md`
cubriendo modelo de datos, privacidad, exclusiones, persistencia, hotkey,
paste vs copy, manual checks.

### 2. Color Picker Pro

Importante y conviene tratarlo como modulo premium de calidad, no como
boton simple. Mejoras que pide la auditoria y que ya tenemos infraestructura
para hacer:

- [x] Screen Recording diagnostico (boton Request Access + copy explicativo).
- [x] Multi-monitor (overlay cubre union de todas las pantallas).
- [ ] Lupa con zoom 8x alrededor del cursor.
- [ ] Grid de pixel central con el valor exacto.
- [ ] Preview del color bajo cursor antes del click.
- [ ] Copia en HEX, RGB, HSL, SwiftUI `Color`, CSS.
- [ ] Historial con favoritos (extender `PickedColor` con `isFavorite`).
- [ ] Colores similares por HSL (RGB → HSL puro, tests deterministicos).
- [ ] Paleta derivada: mas claro, mas oscuro, saturado, desaturado,
      complementario, analogos.

MVP Pro:

- `⌥⌘C` editable abre overlay.
- Zoom 8x alrededor del cursor, snapshot re-render en `mouseMoved`.
- Click copia el formato elegido.
- Panel lateral compacto: color actual, formatos, hex.
- Historial visible en settings con favoritos y filtro por texto.

### 3. Menu Bar Cleaner / Hide Bar Pro

Estabilizar lo que esta + extender:

- [x] Hide/reveal por click (separator + reveal status item).
- [ ] Reveal por hover con delay configurable.
- [ ] Definir grupo "siempre visible" explicito, no solo "lo que no esta
      oculto". Hoy el comportamiento es "todo lo que no este en hiddenItemIds
      es visible", que es correcto pero no da control fino al usuario.
- [ ] Mover iconos de lugar cuando sea tecnicamente posible via
      `kAXPositionAttribute`.
- [ ] Perfiles: trabajo, foco, presentacion (basura → reveal-all,
      foco → todo visible, presentacion → solo reloj y bateria).
- [ ] Reset seguro que restaura todo a visible.

Riesgos que vimos y queremos evitar:

- macOS no notifica cambios en menu bar — ya lo cubrimos con
  `NSWorkspace.didLaunchApplicationNotification` + `didTerminateApplicationNotification`.
  Anadir un observer para `NSWorkspace.didChangeScreenParametersNotification`
  por si el usuario conecta/desconecta pantallas.
- Algunos items del sistema no se pueden mover o vuelven solos. Documentar
  matriz por macOS y por item.

### 4. Screenshot Studio

Despues de region capture, puede crecer a editor ligero. La auditoria
marca como P1 lo de region, como P2 el editor. Construir en este orden:

1. **Region capture**: overlay similar al Color Picker pero drag-based.
   Drag para seleccionar rectangulo, ESC cancela, Enter confirma.
   Captura solo esa region via `ScreenCapture.captureScreen(rect:)`.
2. **Window capture**: clic en una ventana la captura sola. Requiere
   `kCGWindowNumber` → `CGWindowListCreateImage` con el windowID.
3. **Annotaciones**: rectangulo, flecha, texto, lapiz, resaltador, blur.
4. **Color picker del editor**: reusa `ColorPickerModule` via el servicio
   compartido de Core, no importando Color Picker directamente.
5. **Blur/pixelate**: filtro CGImage sobre el area seleccionada antes de
   hornear las anotaciones.

Clave:

- No construir Photoshop. Tiene que abrir rapido, anotar, copiar y cerrar.
- Cada accion es una sola tecla o un solo click. Sin menus anidados.

### 5. Window Snapper

Util en macOS si se hace nativo y simple.

Benchmark principal:

- Rectangle: keyboard shortcuts y snap areas en bordes/esquinas.
- Rectangle Pro: tamanhos personalizados, acciones repetidas, workspaces,
  snap panel y acciones mas avanzadas.

Funciones:

- Hotkeys para izquierda/derecha/maximizar/centrar (todos editables via
  `ShortcutRecorder`).
- Grid simple.
- Mover ventana entre monitores.
- Layouts guardados por pantalla.
- Snap areas al arrastrar ventanas a bordes y esquinas.
- Acciones tipo Rectangle: halves, quarters, thirds, center, maximize,
  almost maximize, maximize height, restore.
- Repetir shortcut para ciclar tamanhos relacionados, por ejemplo
  izquierda mitad → dos tercios → un tercio.

Permisos:

- Accessibility para mover/redimensionar ventanas via AXUIElement.
  El modulo hereda la educacion de Scroll Control sobre por que la
  permission es necesaria.

Riesgos:

- Apps con ventanas custom pueden no responder perfecto. Documentar
  excepciones conocidas en manual checks.
- Multi-monitor y Spaces requieren pruebas manuales cuidadosas.

MVP recomendado:

- Solo ventana activa.
- Acciones basicas por hotkey.
- Restore a posicion anterior.
- Preferencias de margen entre ventanas y borde de pantalla.
- Manual checks por app comun: Finder, Safari, Xcode, Terminal, Slack.

### 6. Quick Launcher / Command Palette

Unifica acciones de DropThings.

Funciones:

- Hotkey global editable (default `⌥⌘K`).
- Buscar modulos y acciones por nombre.
- "Pick color", "Capture region", "Keep awake 30m", "Clear clipboard",
  "Show shelf", "Toggle Scroll Control".
- Acciones recientes.
- Integracion con Spotlight como fallback (`NSUserActivity`).

Ventaja:

- Evita llenar el menu bar de controles.
- Hace que muchos modulos sean accesibles desde teclado.
- Es la unica forma sensata de exponer acciones de modulos futuros
  sin inflar la UI.

Implementacion:

- `CommandPalette` vista SwiftUI sobre `NSPanel` borderless.
- Cada modulo expone `commands: [CommandDescriptor]` via `DropThingsModule`.
  `CommandDescriptor` es Codable con `id`, `title`, `symbolName`, `category`.
- El `CommandPaletteModule` (o AppServices) agrega todos los comandos y
  los muestra en una lista filtrable.

### 7. Text Tools

Utilidades de texto para clipboard o seleccion activa.

Funciones:

- Convertir mayusculas/minusculas/title case.
- URL encode/decode.
- JSON format/minify.
- Base64 encode/decode.
- Limpiar espacios.
- Contar palabras/caracteres.
- Sort lines / unique lines / dedupe.

Permisos:

- Sin permisos para clipboard operations.
- Accessibility solo si modifica seleccion activa. Mantener opcional.

MVP:

- Hotkey `⌥⌘T` para abrir mini ventana con todas las herramientas.
- Input es el texto actual del clipboard (o seleccion si esta vacia).
- Output reemplaza clipboard o escribe en portapapeles via `NSPasteboard`.

### 8. Downloads / File Inbox

Complementa File Shelf.

Funciones:

- Ver descargas recientes (`~/Downloads` ordenado por fecha).
- Arrastrar recientes desde menu bar / palette directo a File Shelf.
- Limpiar duplicados o archivos temporales (.dmg viejos, .pkg).
- Mover a carpetas frecuentes (Desktop, Documents).

Permisos:

- Preferir carpeta elegida por usuario o Downloads.
- Evitar Full Disk Access.

### 9. Focus / Presentation Mode

Modulo para preparar la Mac antes de compartir pantalla.

Funciones:

- Ocultar menu bar items no esenciales (reusa Menu Bar Cleaner).
- Activar Keep Awake (reusa el toggle existente).
- Pausar Clipboard History (cuando exista).
- Silenciar notificaciones si hay API viable.
- Cambiar wallpaper o ocultar desktop icons si se implementa seguro.

Riesgo:

- Puede cruzar demasiadas fronteras. Implementar como workflow que coordina
  modulos existentes, no como modulo que toca todo directamente. Si el
  modulo Focus importa Scroll Control, Menu Bar Cleaner y Keep Awake
  directamente, ya no son modulos aislados.

Alternativa: el workflow vive en AppServices, expone un boton "Present
mode" que toggle cada modulo via su API publica. Ningun modulo sabe
  que Focus Mode existe.

### 10. App Switcher / Window List

Una paleta para encontrar ventanas abiertas.

Funciones:

- Buscar app/ventana por nombre.
- Traer al frente.
- Cerrar/minimizar opcional.

Permisos:

- Accessibility para enumerar/controlar ventanas.

Implementacion:

- `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)`
  da la lista de ventanas sin permisos.
- Para traer al frente: `AXUIElementRaise` que necesita Accessibility.

## Ideas buenas pero diferibles

- **Keyboard remapper**: util, pero muy sensible por permisos y edge cases.
  Requiere IOHIDPostEvent o un event tap global con reescritura. Mejor
  esperar a tener experiencia con EventTapClient.
- **Dock tweaks**: muchas cosas requieren comandos `defaults` o reiniciar Dock.
  La persistencia y el orden del Dock son fragiles. No prioritario.
- **Audio device switcher**: util y menos riesgoso. Buen candidato simple
  para v3. API publica via `AudioObjectSetPropertyData`.
- **Wi-Fi/Bluetooth quick toggles**: APIs limitadas en macOS recientes (Catalina+
  endurecio permissions). Revisar viabilidad.
- **Pomodoro/focus timer**: facil, pero menos diferencial. Esperar a que
  Focus Mode exista y agregar timer ahi.
- **OCR desde captura**: potente, pero agrega Vision flow y privacidad.
  Considerar opt-in.
- **QR generator/reader desde clipboard**: pequeno y util.
- **Unit converter**: facil, pero menos conectado al sistema.

## Orden sugerido de construccion (revisado 2026-06-28)

1. **Color Picker Pro** — estabilizar lo que el usuario usa hoy. La
   auditoria es concreta y la infraestructura ya esta.
2. **Clipboard History** — siguiente modulo grande. Hacer auditoria previa
   (`clipboard-history-auditoria.md`) antes de implementar.
3. **Command Palette** — antes de cualquier modulo nuevo grande, esto
   ordena las acciones existentes. Vale hacerlo temprano.
4. **Menu Bar Cleaner Pro** — hover-to-reveal, perfiles. Refina lo que
   tenemos.
5. **Screenshot region capture** — paso previo a las anotaciones.
6. **Window Snapper** — depende de madurez con Accessibility. Despues de
   Scroll Control tener experiencia.
7. **Screenshot annotations**.
8. **Text Tools** — modulo pequeno, buen cierre de v2.
9. **Focus Mode** — workflow cross-modulo, ultimo porque requiere que
   los modulos individuales esten maduros.
10. **Downloads / File Inbox** — complemento de File Shelf, momento en
    que el usuario ya tiene pin/persistencia.
11. **App Switcher** — Accessibility intensivamente, ultimo.

## Integraciones entre modulos (sin imports directos)

Reglas claras que aplican a futuro:

- **Eventos publicados via Core**, no via callbacks. Ejemplo: Color Picker
  publica `colorPicked` evento via un `EventBus` o `AsyncStream` en Core.
- **Clipboard History escucha eventos** de clipboard y puede mostrar colores
  enriquecidos cuando Color Picker emite `colorPicked`.
- **Screenshot puede usar Color Picker** solo a traves de servicios compartidos
  de color/formato en Core, no importando el modulo.
- **Focus Mode coordina modulos por Core**, no llamando implementaciones
  privadas de cada modulo.
- **Command Palette lista acciones registradas por modulos en Core.**
  Cada modulo expone `commands: [CommandDescriptor]`. Core los agrega
  al catalogo global. La palette los muestra filtrados.
- **Settings import/export ya existe** — cualquier modulo nuevo debe
  adherirse al patron Codable + JSON para que `defaults export` lo incluya
  sin tocar SettingsImporter.

## Documentacion previa recomendada

Antes de implementar cualquier modulo nuevo, crear el archivo de auditoria
correspondiente en `docs/modulos/<modulo>-auditoria.md`. Debe cubrir:

- Estado actual (si hay v0 previo) y gaps conocidos.
- Permisos: que necesita realmente y por que.
- Modelo de datos propuesto.
- Edge cases y modos de falla.
- Manual checks iniciales.

Auditoria pendiente: `clipboard-history-auditoria.md`, `window-snapper-auditoria.md`,
`command-palette-auditoria.md`.

## Riesgo general a tener en cuenta

Cada modulo nuevo suma complejidad operativa: TCC entries, hotkeys, settings,
manual checks. La regla practica: si un modulo no se usa semanalmente por
el 80% del publico objetivo, no entra. DropThings gana siendo pequeno,
no siendo un kitchen sink.
