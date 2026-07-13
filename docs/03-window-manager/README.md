# Window Manager

This folder defines the Rectangle replacement. Target parity is Rectangle's
core window positioning and drag snapping, not Rectangle Pro automation.

## Read order

1. `PRODUCT.md`
2. `ARCHITECTURE.md`
3. `EXPERIENCE.md`
4. `IMPLEMENTATION.md`
5. `QUALITY.md`
6. `RESEARCH-AND-LICENSES.md`
7. `AGENT-RUNBOOK.md`

## Definition of done

- Keyboard and drag-to-edge placement cover halves, quarters, thirds, two
  thirds, maximize, center, restore, and moving between displays.
- Repeating a shortcut cycles predictable sizes/positions.
- The correct previous frame is restored per window.
- Mixed-scale/negative-origin displays, Dock/menu bar/notch, Spaces, full-screen,
  and nonstandard app windows fail safely.
- Accessibility is requested only when the module is enabled.
- The owner can remove Rectangle without losing an in-scope workflow.

## Current baseline

`WindowSnapModule` and `WindowSnapper` already move the focused window through
Accessibility and calculate nine targets: maximize, four halves, and four
quarters. Hotkeys/settings/permission health exist. Missing pieces include drag
snapping, preview footprint, restore history, repeated cycles, thirds, display
movement, richer error handling, and normal test-target inclusion.

## Delivery order

1. Make the current geometry and adapter testable.
2. Reach complete keyboard parity.
3. Add history, cycling, and multi-display movement.
4. Add drag snapping and footprint preview.
5. Harden exceptional applications/configurations.
