# Permisos Y Diagnostico - Auditoria Transversal

## Problema reportado

"Ya le di acceso en Accessibility y nada, sigue sin funcionar."

La causa mas probable depende del modulo:

- Scroll Control y parte de Menu Bar Cleaner: necesitan Accessibility.
- Color Picker: necesita Screen Recording.
- Screenshot: necesita Screen Recording.
- Keep Awake: no necesita permisos.

Entonces, si el problema era Color Picker o Screenshot, dar Accessibility no
lo destraba. Hay que otorgar Screen Recording al mismo bundle/path de
DropThings que se esta ejecutando.

## Hallazgos

### P0 - Razones de permisos demasiado genericas

`SystemPermission.screenRecording.reason` dice que sirve para detectar items
del menu bar visualmente. Ahora tambien lo usan Color Picker y Screenshot,
por lo que la razon global quedo incompleta.

Plan:

- Mantener una razon generica en `SystemPermission`.
- Permitir que cada modulo provea una razon especifica por permiso.
- Mostrar esa razon en `PermissionRow`.

Ejemplos:

- Color Picker: "Lee pixeles de la pantalla para copiar el color elegido."
- Screenshot: "Captura lo que esta visible para guardar o copiar una imagen."
- Menu Bar Cleaner: "Inspecciona visualmente items cuando Accessibility no
  alcanza."

### P0 - Falta accion de diagnostico por modulo

El usuario necesita saber que permiso falta y que build de la app recibio el
permiso.

Plan:

- En cada modulo con permisos, mostrar:
  - permiso requerido;
  - estado actual;
  - bundle id;
  - path de la app;
  - boton refresh;
  - boton request access.
- Agregar copy "Si cambiaste de build, macOS puede tratarla como otra app".

### P0 - Reset TCC documentado por permiso

Ya existe un hint general en Diagnostics, pero conviene hacerlo especifico.

Comandos utiles:

```bash
tccutil reset Accessibility app.dropthings
tccutil reset ScreenCapture app.dropthings
```

Despues:

1. Cerrar DropThings.
2. Abrir el build exacto que se va a usar.
3. Entrar al modulo.
4. Presionar Request Access.
5. Volver a DropThings y Refresh permissions.

### P1 - Estado `denied` vs `notDetermined`

El backend actual devuelve `notDetermined` cuando no esta otorgado para
Accessibility y Screen Recording. Para el usuario eso alcanza, pero para
diagnostico seria mejor distinguir:

- nunca pedido;
- pedido y negado;
- otorgado a otro path/build;
- otorgado pero el modulo fallo por otra causa.

macOS no siempre permite distinguir todo via API publica, asi que el plan
debe ser pragmatico: estado tecnico + instruccion clara.

### P1 - Logs visibles en UI

Hay logs por categoria, pero cuando falla una accion directa, la UI deberia
mostrar el ultimo error.

Plan:

- Agregar `lastUserVisibleError` por modulo o un servicio compartido de
  eventos accionables.
- El detalle del modulo muestra el error mas reciente y una accion.
- Diagnostics sigue mostrando el historico.

### P1 - Lazyweb/design gate

No se cambio UI en esta auditoria. Antes de implementar nuevas pantallas de
permisos, editor de screenshots o picker avanzado, correr el workflow
Lazyweb registrado en `docs/research/lazyweb.md` y guardar el resultado o
nota.

## Checklist cuando "no funciona"

1. Confirmar que modulo es.
2. Confirmar permiso real:
   - Keep Awake: ninguno.
   - Color Picker: Screen Recording.
   - Screenshot: Screen Recording.
   - Scroll/Menu Bar: Accessibility y posiblemente Screen Recording.
3. Abrir Diagnostics y copiar bundle id/path.
4. Resetear el permiso correcto con `tccutil` si macOS quedo trabado.
5. Relanzar el mismo `.app`.
6. Presionar Request Access desde DropThings.
7. Refresh permissions.
8. Revisar Console.app con `subsystem: app.dropthings`.

