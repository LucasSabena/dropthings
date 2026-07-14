# Experience contract

## Primary surface

- Compact list of active/pinned apps with icon, name, meter, mute, and volume.
- Master/default output and current device are visible without entering settings.
- Advanced routing/EQ is disclosed per app; it does not make every row tall.
- System/helper processes are hidden by default but discoverable in diagnostics.
- A degraded app/device shows a local warning without disabling healthy rows.
- Audio Control has an independent menu-bar icon by default while the module is
  enabled. Its settings include a `Show in menu bar` switch; turning it off
  removes only this shortcut, not the module or the main DropThings item.
- The compact menu-bar surface exposes system output selection, system volume
  and mute, per-app volume/mute/solo, per-app routing, and app actions.
- The compact surface always reserves a small Media controls card. When macOS
  exposes an active Now Playing session, it shows its source app, title,
  artist/album, and previous/play-pause/next controls; otherwise it clearly
  says that nothing is playing.
- The footer opens this module's settings and offers Quit. DropThings does not
  copy FineTune's donation/marketing affordance.

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
- Menu-bar icons use template SF Symbols, keep a tooltip/VoiceOver label, and
  disappear immediately when their module is disabled or their visibility
  preference is turned off.

## Refinement note — 2026-07-14

The menu-bar symbol now reflects live master
output: muted/zero, low, medium, and high volume use progressively distinct SF
Symbols. The shared popover is transient and no longer forces itself key. It
closes when the user returns to another application, while internal controls
remain usable.

## Discovery reliability — 2026-07-14

Multi-process applications are presented under their owning app name rather
than a renderer/helper name. Once discovered, a row stays visible as `Idle`
until that application quits, instead of disappearing during Core Audio stream
handoffs or silence. Idle rows are never processed or muted; they only preserve
a stable, understandable UI.

Transport controls for third-party players remain a separately specified phase:
macOS has no public universal API to control arbitrary apps' playback. This
module must not emulate media keys with undocumented event APIs.
