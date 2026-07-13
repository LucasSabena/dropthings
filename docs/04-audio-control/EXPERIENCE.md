# Experience contract

## Lazyweb workflow note — 2026-07-13

Lazyweb was queried first for desktop audio mixers, equalizers, per-app volume,
and routing surfaces. Its accessible indexed corpus did not expose a directly
relevant FineTune/SoundSource macOS flow. The product therefore follows native
menu-bar mixer conventions and inspected FineTune behavior; no Lazyweb asset or
unsupported benchmark is used.

Lazyweb entry point: <https://www.lazyweb.com/>

## Primary surface

- Compact list of active/pinned apps with icon, name, meter, mute, and volume.
- Master/default output and current device are visible without entering settings.
- Advanced routing/EQ is disclosed per app; it does not make every row tall.
- System/helper processes are hidden by default but discoverable in diagnostics.
- A degraded app/device shows a local warning without disabling healthy rows.

## Safety interaction

- Boost above 100% is visually distinct and explained once; default is off.
- Switching/bypassing/routing uses a short gain ramp; never produce a sudden full-
  volume burst.
- If an engine failure risks silence/echo, the UI prioritizes “Restore normal
  audio” over preserving settings.
- Mute/solo states are unmistakable and keyboard accessible.

## Permission boundary

- Before the first prompt, explain that macOS calls this System Audio Recording,
  that DropThings processes sound locally to change app volume, and that it does
  not save/transmit audio.
- Denial leaves the module off/needs permission and ordinary audio untouched.
- Settings provide the correct System Settings destination and recheck on return.

## States

- Loading apps/devices never shows an empty healthy state without explanation.
- Helper restarting shows bounded progress and a cancel/disable path.
- Device disconnected rows retain intended routing visibly but name the fallback.
- Unsupported macOS shows requirements without offering a permission button.

## Accessibility and visuals

- Use standard sliders/toggles/popovers and shared design tokens.
- Sliders have numeric values, increment/decrement actions, mute shortcut, and
  VoiceOver labels including app/device context.
- Meter color is not the only clipping indication; expose text/icon state.
- Respect Reduce Motion and avoid high-frequency visual updates when the popup is
  closed or VoiceOver would be overwhelmed.
