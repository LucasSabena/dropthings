# Backlog De Modulos Futuros

Fecha: 2026-06-28

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

## Prioridad recomendada

### 1. Clipboard History

Este deberia ser uno de los modulos centrales.

Problema:

- macOS tiene un clipboard unico y se pierde rapido lo copiado.
- Desarrolladores, diseno y trabajo diario necesitan recuperar texto,
  links, colores, imagenes y archivos recientes.

MVP:

- Hotkey global para abrir historial.
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
- Colores copiados por Color Picker.
- Archivos como referencias, no duplicando contenido.

Permisos:

- Puede leer `NSPasteboard` sin Accessibility para historial basico.
- Para pegar automaticamente en la app activa puede necesitar Accessibility
  o simulacion de teclado. Mantenerlo opcional.

Privacidad:

- Excluir apps sensibles.
- Opcion "no guardar contrasenas" basada en tipos de pasteboard cuando sea
  posible.
- Modo incognito temporal.
- Cifrado/local-only si se persiste historial.

Arquitectura sugerida:

- `ClipboardModule` en `Modules`.
- `PasteboardMonitor` en `Platform`.
- `ClipboardStore` con limite, pins y expiracion.
- Integracion opcional con Color Picker para que colores copiados aparezcan
  como items enriquecidos.

### 2. Color Picker Pro

Este es importante y conviene tratarlo como modulo premium de calidad, no
como boton simple.

Mejoras criticas:

- Arreglar Screen Recording y diagnostico.
- Resolver multi-monitor.
- Lupa con zoom.
- Grid de pixel central.
- Preview del color bajo cursor.
- Copia en HEX, RGB, HSL, SwiftUI, CSS.
- Historial con favoritos.
- Colores similares por HSL.
- Paleta derivada: claro, oscuro, saturado, desaturado, complementario,
  analogos.

MVP Pro:

- `Option + Command + C` abre overlay.
- Zoom 8x alrededor del cursor.
- Click copia el formato elegido.
- Panel lateral compacto con color actual y formatos.
- Historial visible en settings y en Clipboard History.

### 3. Menu Bar Cleaner / Hide Bar Pro

El objetivo no es solo ocultar iconos; tambien ordenar.

Funciones:

- Definir grupo visible y grupo oculto.
- Reveal por click, hover o hotkey.
- Mover iconos de lugar cuando sea tecnicamente posible.
- Separador/handle propio de DropThings.
- Perfiles: trabajo, foco, presentacion.
- Reset seguro.

Riesgos:

- Es el modulo mas fragil por macOS version.
- Mover iconos de terceros puede depender de Accessibility y detalles de UI.
- Algunos items del sistema no se pueden mover o vuelven solos.

Plan:

- Primero estabilizar hide/reveal.
- Despues agregar reorder manual por lista en settings.
- Luego intentar drag/reorder visual solo si el adapter lo soporta bien.
- Documentar matriz por macOS y notch/small screens.

### 4. Screenshot Studio

Despues de region capture, puede crecer a editor ligero.

Funciones:

- Captura completa.
- Captura por region.
- Captura de ventana.
- Anotaciones: flecha, rectangulo, texto, lapiz, resaltador.
- Blur/pixelate para ocultar datos.
- Copiar/guardar automaticamente.
- Ultimas capturas.

Clave:

- No construir Photoshop. Tiene que abrir rapido, anotar, copiar y cerrar.

### 5. Window Snapper

Muy util en macOS si se hace nativo y simple.

Benchmark principal:

- Rectangle: keyboard shortcuts y snap areas en bordes/esquinas.
- Rectangle Pro: tamaños personalizados, acciones repetidas, workspaces,
  snap panel y acciones mas avanzadas.

Funciones:

- Hotkeys para izquierda/derecha/maximizar/centrar.
- Grid simple.
- Mover ventana entre monitores.
- Layouts guardados por pantalla.
- Snap areas al arrastrar ventanas a bordes y esquinas.
- Acciones tipo Rectangle: halves, quarters, thirds, center, maximize,
  almost maximize, maximize height, restore.
- Repetir shortcut para ciclar tamanos relacionados, por ejemplo izquierda
  mitad -> dos tercios -> un tercio.

Permisos:

- Accessibility para mover/redimensionar ventanas.

Riesgos:

- Apps con ventanas custom pueden no responder perfecto.
- Multi-monitor y Spaces requieren pruebas manuales.

MVP recomendado:

- Solo ventana activa.
- Acciones basicas por hotkey.
- Restore a posicion anterior.
- Preferencias de margen entre ventanas y borde de pantalla.
- Manual checks por app comun: Finder, Safari, Xcode, Terminal, Slack.

### 6. Quick Launcher / Command Palette

Unifica acciones de DropThings.

Funciones:

- Hotkey global.
- Buscar modulos y acciones.
- "Pick color", "Capture region", "Keep awake 30m", "Clear clipboard",
  "Show shelf".
- Acciones recientes.

Ventaja:

- Evita llenar el menu bar de controles.
- Hace que muchos modulos sean accesibles desde teclado.

### 7. Text Tools

Utilidades de texto para clipboard/seleccion.

Funciones:

- Convertir mayusculas/minusculas/title case.
- URL encode/decode.
- JSON format/minify.
- Base64 encode/decode.
- Limpiar espacios.
- Contar palabras/caracteres.

Permisos:

- Sin permisos si trabaja sobre clipboard.
- Accessibility solo si modifica seleccion activa.

### 8. Downloads / File Inbox

Complementa File Shelf.

Funciones:

- Ver descargas recientes.
- Arrastrar recientes desde menu.
- Limpiar duplicados o archivos temporales.
- Mover a carpetas frecuentes.

Permisos:

- Preferir carpeta elegida por usuario o Downloads.
- Evitar Full Disk Access.

### 9. Focus / Presentation Mode

Modulo para preparar la Mac antes de compartir pantalla.

Funciones:

- Ocultar menu bar items no esenciales.
- Activar Keep Awake.
- Pausar Clipboard History.
- Silenciar notificaciones si hay API viable.
- Cambiar wallpaper o ocultar desktop icons si se implementa seguro.

Riesgo:

- Puede cruzar demasiadas fronteras. Implementar como workflow que coordina
  modulos existentes, no como modulo que toca todo directamente.

### 10. App Switcher / Window List

Una paleta para encontrar ventanas abiertas.

Funciones:

- Buscar app/ventana por nombre.
- Traer al frente.
- Cerrar/minimizar opcional.

Permisos:

- Accessibility para enumerar/controlar ventanas.

## Ideas buenas pero diferibles

- Keyboard remapper: util, pero muy sensible por permisos y edge cases.
- Dock tweaks: muchas cosas requieren comandos defaults o reiniciar Dock.
- Audio device switcher: util y menos riesgoso, buen candidato simple.
- Wi-Fi/Bluetooth quick toggles: APIs limitadas, revisar viabilidad.
- Pomodoro/focus timer: facil, pero menos diferencial.
- OCR desde captura: potente, pero agrega Vision flow y privacidad.
- QR generator/reader desde clipboard: pequeno y util.
- Unit converter: facil, pero menos conectado al sistema.

## Orden sugerido de construccion

1. Arreglar Color Picker hasta que sea confiable.
2. Agregar Clipboard History MVP.
3. Mejorar Menu Bar Cleaner con hide/reveal estable.
4. Screenshot region capture.
5. Command Palette para unir acciones.
6. Screenshot annotations.
7. Window Snapper.
8. Text Tools.

## Integraciones entre modulos

Integrar sin dependencias directas:

- Color Picker publica evento `colorPicked`.
- Clipboard History escucha eventos de clipboard y puede mostrar colores
  enriquecidos.
- Screenshot puede usar Color Picker solo a traves de servicios compartidos
  de color/formato, no importando el modulo.
- Focus Mode coordina modulos por `Core`, no llamando implementaciones
  privadas.
- Command Palette lista acciones registradas por modulos en `Core`.

## Proximo documento recomendado

Crear `clipboard-history-auditoria.md` antes de implementar. Debe cubrir:

- Modelo de datos.
- Privacidad.
- Exclusiones por app.
- Persistencia.
- Hotkey.
- Pegar automatico vs copiar solamente.
- Manual checks.
