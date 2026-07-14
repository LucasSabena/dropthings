# Audio Control menu-bar visual QA

- Source visual truth: `/var/folders/gb/c3m0lk453g13jfvpp17tm32w0000gn/T/TemporaryItems/NSIRD_screencaptureui_wzfBUg/Captura de pantalla 2026-07-13 a las 8.57.49 p. m..png`
- Final implementation screenshot: `/tmp/dropthings-audio-qa/implementation-pass-3.jpeg`
- Final comparison: `/tmp/dropthings-audio-qa/comparison-pass-3.png`
- Viewport: native 480×520 pt module surface; source popover normalized to the
  same 520 px height for the combined comparison.
- State: dark appearance, built-in output at 37%, no apps currently playing.
- Primary interactions tested: output menu exposed and enabled; master mute and
  slider expose labels/values/actions; Settings and Quit are reachable. Per-app
  command delegation and route persistence are covered by automated tests because
  the visual target is the empty state.

**Full-view comparison evidence**

The source and implementation were placed in one combined image before review.
Both show the same hierarchy: output selector, master output row with numeric
volume, separated Apps section, centered mute/empty state, and persistent footer.
DropThings intentionally uses a 480 pt native utility width rather than the much
wider FineTune panel, and replaces Donate with the module identity plus Settings
in accordance with the product's no-marketing rule. The Debug preview adds macOS
traffic lights; the shipping `NSPopover` does not.

**Focused region evidence**

No extra crop was needed: the normalized full comparison preserves the entire
480×520 implementation at native resolution, and all typography, SF Symbols,
slider geometry, separators, footer controls, and copy remain legible. The
Computer Use accessibility tree was checked alongside the combined image.

**Findings**

- No remaining P0/P1/P2 mismatches.
- [P3] The source includes microphone/edit affordances that are outside the
  requested output/per-app mixer slice and remain later Audio Control work.
- The implementation's explanatory empty-state sentence is intentional and
  improves first-use clarity without changing the source hierarchy.

**Comparison history**

1. Pass 1 (`/tmp/dropthings-audio-qa/comparison-pass-1.png`): P2 — disabling the
   unavailable output menu dimmed the full header below useful contrast.
2. Fix: kept the output menu enabled with a disabled `No outputs available`
   command, so the label stays readable while truthfully representing state.
3. Pass 2 (`/tmp/dropthings-audio-qa/comparison-pass-2.png`): contrast issue fixed;
   external device state still differed from the source.
4. Pass 3 (`/tmp/dropthings-audio-qa/comparison-pass-3.png`): used the Debug-only
   deterministic 37% built-in-output state, matching the source state. No
   actionable P0/P1/P2 difference remained.

**Implementation checklist**

- [x] Preserve source information hierarchy in the compact native surface.
- [x] Use shared semantic tokens and real SF Symbols/application icons.
- [x] Keep empty/loading/error states readable and accessible.
- [x] Verify final output in a combined source/implementation comparison.

final result: passed
