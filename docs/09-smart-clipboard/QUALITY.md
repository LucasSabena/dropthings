# Quality and verification

## Safety invariants

- One hotkey opens contextual actions for text, URL, JSON, color, file URLs, images and rich text.
- Every transform previews locally; no LLM, hidden mutation or automatic network call.
- Clipboard History and Smart Clipboard together use one observer and create no duplicate/self-trigger loops.
- Users can copy a result, optionally paste it back to the prior app, create a file or invoke compatible registered file actions.
- Diagnostics never include clipboard payloads.

## Automated and fault tests

- Snapshot sequence/origin/subscriber lifecycle and identical external copies versus self-authored writes.
- Spanish/English/Unicode classifier ambiguity, JSON limits/errors, color alpha/ranges and stable line transformations.
- Clipboard History alone, Smart Clipboard alone, both enabled, rapid enable/disable and app termination.
- Large image, promised/stale file, malformed RTF, hotkey conflict, target app quit and focus restore failure.
- 1,000 synthetic changes remain bounded and typical text panel opens perceptually immediately.

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
