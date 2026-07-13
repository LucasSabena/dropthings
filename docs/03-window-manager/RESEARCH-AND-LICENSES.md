# Research and licenses

Last researched: 2026-07-13.

## Primary technical sources

- Apple AXUIElement: controls accessible applications and may return
  `kAXErrorNotImplemented` when an app does not support an operation:
  <https://developer.apple.com/documentation/applicationservices/axuielement_h>
- Apple `NSWorkspace` for active/running app lifecycle:
  <https://developer.apple.com/documentation/appkit/nsworkspace>
- Rectangle repository/behavior: <https://github.com/rxhanson/Rectangle>

## Rectangle inspection

- Inspected commit: `2c662c134b2560636e63eed5e5c3def7c886cddf`.
- License: MIT, copyright Ryan Hanson 2019–2026; based on Spectacle,
  copyright Eric Czarny 2017.
- Snapshot scale: 176 Swift/Objective-C header/implementation files,
  approximately 21,596 lines.
- Relevant directories: `Rectangle/Snapping`, `WindowCalculation`, and
  `WindowMover`.
- Notable design evidence: dedicated footprint window; separate snapping
  manager; compound snap-area calculations; best-effort/fixed-size/standard
  movers; explicit repeated-execution calculations.
- Decision: selective adaptation is allowed. Prefer DropThings' smaller pure
  geometry engine; copy only behavior/code that materially reduces risk.

## Lazyweb record

Lazyweb was consulted first as recorded in `EXPERIENCE.md`; no code/assets were
copied.

## Reuse ledger

No Rectangle source has yet been copied into DropThings as of 2026-07-13.

| DropThings file | Rectangle source file | Commit | License | Modification |
| --- | --- | --- | --- | --- |
| _none_ | | | | |

For substantial copies, preserve the Rectangle/Spectacle MIT notice in the
repository and source comment, record exact paths here, and do not copy
Rectangle branding/assets. DropThings' combined project is GPL-3.0-only; the MIT
source remains attributable and may be included in that GPL work.
