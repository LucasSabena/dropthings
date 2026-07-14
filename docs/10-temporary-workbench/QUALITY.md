# Quality and verification

## Safety invariants

- Create a board, drop images/files/URLs/text, draw/connect ideas, close and reopen without loss.
- Boards are portable .dropboard packages with autosave, atomic save, crash recovery and explicit embedded/linked assets.
- Canvas remains responsive on a realistic design-reference board and supports keyboard plus pointer/trackpad workflows.
- Export full board or frames to PNG/PDF and clearly manage temporary versus saved projects.
- No account, cloud sync, collaboration or AI generation is required.

## Automated and fault tests

- Geometry, hit testing, transforms, grouping/connectors, semantic undo coalescing and bounded history.
- Schema decode/validation/migrations, unknown item preservation, finite coordinates and asset dedup/bookmarks.
- Fault injection during asset copy, JSON write, staging move, thumbnail and final replacement.
- Force quit during dirty/autosave/Save As; missing/modified links; huge tiled export and cancellation.
- Performance: 300 mixed items smooth on owner hardware; 1,000 lightweight items remain usable; 100 open/close cycles leak no controllers.

## Manual matrix

- Permission deny, grant and revoke paths relevant to the product.
- Normal files/content plus corrupt, missing, huge and hostile-name cases.
- App termination, sleep/wake, device/destination changes and low disk/memory.
- Keyboard-only, VoiceOver, Reduce Motion and high-contrast behavior.
- Debug and Release builds, packaging/signature and migration from existing user
  settings.

## Evidence required

- Hardware, macOS and Xcode versions.
- Full `swift test --parallel` result.
- Debug and Release Xcode build results.
- CPU, memory, elapsed time and resource/temp inventories for long-running work.
- Screenshots of empty, normal, active, degraded, failure and recovery states.
- Known limitations and unsupported capabilities.

## Release gate

- No safety invariant lacks evidence.
- Full suite and product-specific matrices pass.
- No user content appears in default logs.
- Seven days of owner daily use for the core workflow.
- Documentation and research ledger match the exact shipped implementation.
- Module remains unregistered until the gate is complete.
