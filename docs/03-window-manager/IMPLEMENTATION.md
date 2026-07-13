# Implementation plan

## Phase 0 — baseline and test inclusion

- [ ] Include WindowSnap/WindowSnapper and tests in normal SwiftPM/Xcode test
  paths or document the exact supported target boundary.
- [ ] Add golden geometry tests for all existing actions and screen origins.
- [ ] Split AX snapshot/apply from pure geometry without visible regression.
- [ ] Add settings migration path for renamed module/actions.

Gate: current nine actions and permission states pass automated/manual tests.

## Phase 1 — keyboard parity

- [ ] Add thirds, two-thirds, almost maximize, center, and restore.
- [ ] Implement robust eligibility/capability checks and typed outcomes.
- [ ] Reread actual frame after AX writes and eliminate coordinate/pixel drift.
- [ ] Add configurable gaps and ignored apps.

Gate: all actions work on the core application/manual matrix.

## Phase 2 — cycles, history, and displays

- [ ] Add session window identity and bounded frame history.
- [ ] Implement configurable repeated-action cycles and reset policy.
- [ ] Move to next/previous display preserving normalized geometry.
- [ ] Observe window/app destruction/manual changes enough to expire stale state.

Gate: restore never moves a different/reused window and cycles are deterministic.

## Phase 3 — drag snapping

- [ ] Implement narrow drag/event adapter and state machine.
- [ ] Resolve edge/corner areas across all displays.
- [ ] Add click-through footprint panel and modifiers/hysteresis.
- [ ] Guarantee cleanup on cancel, permission revoke, app exit, display change,
  and module disable.

Gate: 500 scripted/manual drag cycles leave no stuck preview/monitor and apply
only on intended mouse-up.

## Phase 4 — replacement hardening

- [ ] Validate application exceptions and add minimal per-app compatibility only
  for observed failures.
- [ ] Complete mixed-display/Spaces/Stage Manager/full-screen matrix.
- [ ] Add diagnostics and latency signposts.

Gate: 14 consecutive days without Rectangle for in-scope behavior.
