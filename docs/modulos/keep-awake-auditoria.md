# Keep Awake - Auditoria Y Plan

## Estado actual

El modulo ya usa `KeepAwakeAssertion` en `Platform`, que envuelve
`IOPMAssertionCreateWithName` y `IOPMAssertionRelease`. La implementacion es
pequena y bien aislada.

Comportamiento actual:

- No requiere permisos.
- Permite activar/desactivar mantener despierta la Mac.
- Permite elegir entre prevenir sleep del sistema o sleep de display.
- Libera la assertion al apagar el modulo.

## Hallazgos

### P0 - La preferencia no persiste

`preferredReason` vive solo en memoria. Si el usuario elige "display sleep
only", al relanzar vuelve a `systemSleep`.

Plan:

- Crear `KeepAwakeSettings`.
- Persistir `preferredReason`.
- Guardar si se quiere reactivar automaticamente al abrir la app, con una
  decision explicita de producto.

Criterio de aceptacion:

- Cambiar modo, cerrar DropThings y abrir de nuevo mantiene la eleccion.

### P0 - El estado de error no llega claro a la UI

`applyState` loguea warning si falla la assertion, pero el modulo queda sin
una razon visible para el usuario.

Plan:

- Convertir fallos de `KeepAwakeAssertion` en `ModuleState.failed` o
  `degraded`.
- Mostrar una recuperacion corta: "Reintenta, o revisa si macOS esta en
  modo bateria critica".

Criterio de aceptacion:

- Un fallo simulado produce un estado visible en el detalle del modulo.

### P1 - Falta modo temporal

La funcion mas util en el dia a dia suele ser "mantener despierta por 15m,
30m, 1h, hasta que termine esta sesion".

Plan:

- Agregar opciones: indefinido, 15m, 30m, 1h, 2h.
- Usar un timer del modulo, no estado global.
- Al vencer, liberar assertion y registrar evento.

Criterio de aceptacion:

- El usuario puede activar 15m, ver tiempo restante y al finalizar se apaga.

### P1 - Falta visibilidad desde menu bar

Si el modulo esta activo, conviene que el menu bar lo haga obvio sin abrir
settings.

Plan:

- Agregar accion rapida en el menu: activar/desactivar Keep Awake.
- Mostrar estado corto: "Awake: on/off" o icono activo.
- Mantener UI compacta y nativa.

### P2 - Presets y reglas

Ideas futuras:

- Mantener despierta solo con cargador conectado.
- Mantener despierta durante llamadas o pantalla compartida si se detecta
  de forma confiable.
- Scheduler por dias/horas.

No implementar hasta que haya una necesidad real: puede volverse demasiado
inteligente para una herramienta que debe ser confiable.

## Tests sugeridos

- Unit test de settings round-trip.
- Fake de assertion para simular exito/fallo.
- Manual: `pmset -g assertions` debe mostrar y dejar de mostrar DropThings.

