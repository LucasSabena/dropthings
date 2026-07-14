# Keep Awake experience

## Workflow note — 2026-07-14

Lazyweb was unavailable in the active Codex toolset. This simplification uses
the native macOS module lifecycle already present in DropThings and introduces
no external visual asset.

- There is one authoritative switch: the module enable toggle.
- Enabled means the power assertion is active; disabled means it is released.
- The settings surface reports that state and only retains the optional
  “also keep display awake” preference.
- An explicitly pinned menu-bar icon remains available when disabled. Moon is
  off; sun is on. Clicking it toggles the module lifecycle directly.
- Legacy timed-session values migrate to indefinite operation because an
  enabled-but-expired module would recreate the ambiguity this design removes.
