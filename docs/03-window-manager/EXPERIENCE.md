# Experience contract

## Lazyweb workflow note — 2026-07-13

Lazyweb was queried first for desktop window-manager settings, snap footprints,
and shortcut configuration. Its accessible indexed corpus did not expose a
directly relevant Rectangle/macOS desktop workflow. UI decisions therefore use
native macOS conventions plus observed Rectangle behavior; no Lazyweb asset or
unsupported benchmark is used.

Lazyweb entry point: <https://www.lazyweb.com/>

## Keyboard experience

- Actions feel immediate and never bring DropThings settings to front.
- Repeated-action cycles are predictable and documented beside shortcut rows.
- If the active app has no eligible window, fail quietly with optional transient
  feedback; diagnostics retain the detailed reason.
- Permission loss produces one actionable explanation, not repeated prompts.

## Drag experience

- Footprint appears only after entering a real snap area and disappears as soon
  as it is no longer applicable.
- Preview is click-through, does not steal focus, uses the destination visible
  frame, and respects Reduce Motion/Increase Contrast.
- Apply on mouse-up, not mere edge hover.
- Small accidental edge touches should not snap: use brief hysteresis/distance,
  never a long delay that makes the module feel broken.
- A visible modifier affordance is allowed in settings/help, not as permanent
  overlay clutter.

## Settings

- Group common actions first; advanced actions remain searchable/collapsible.
- Use the shared `ShortcutRecorder` and design tokens.
- Detect duplicate shortcuts as the user records them.
- Offer Restore Defaults per section and describe cycle order explicitly.
- Show Accessibility status and one direct System Settings action.

## Accessibility

- Settings are completely keyboard and VoiceOver usable.
- Preview uses sufficient contrast and is not the sole indication of the action;
  optional action-name feedback may be announced.
- Do not animate window frames by issuing dozens of AX mutations; use immediate
  placement and only subtle footprint animation.
