# Agent runbook

## Before editing

1. Read every file here and root `AGENTS.md`.
2. Confirm current macOS/Xcode/hardware and capture baseline audio behavior.
3. Preserve unrelated changes; choose one phase slice only.
4. Repeat/extend Lazyweb before UI changes.
5. Update the FineTune reuse ledger before copying/adapting source.
6. For Phase 0, use a disposable branch/worktree and record cleanup instructions.

## Hard constraints

- No final in-process audio engine.
- No private APIs, virtual driver installation, kernel/system extension, network
  audio, recording to disk, or microphone capture without new approval/spec.
- No System Audio Recording prompt before explicit enable/invocation.
- IO callback obeys every real-time rule in `ARCHITECTURE.md`.
- Any resource-creation failure unwinds to normal unmuted audio.
- Stable bundle/device UIDs persist; AudioObjectIDs/PIDs do not.
- Never uninstall FineTune until all replacement gates pass and the owner agrees.

## Completion loop

1. Add pure/fake-HAL tests and a precise fault case.
2. Implement the smallest safe end-to-end slice.
3. Run targeted/full tests and Xcode build.
4. Run the applicable hardware/application matrix at safe listening levels.
5. Inventory taps/aggregate devices before and after failures.
6. Record performance, limitations, reuse, and checklist evidence.

## Immediate stop conditions

Stop, restore normal audio, and report if any test leaves silence/echo after
disable/quit, an orphan resource, unexplained device mutation, uncontrolled
volume burst/clipping, callback allocation/lock, repeated helper crash, or a need
for undocumented/private API behavior.
