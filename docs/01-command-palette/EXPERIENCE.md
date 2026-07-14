# Experience contract

## Lazyweb workflow note — 2026-07-13

Lazyweb was consulted before defining this UI. Its accessible corpus includes a
Raycast “ask AI and switch” flow showing a global search surface with quick
destinations and a persistent query affordance. The useful general pattern is
fast keyboard-first entry with progressive disclosure; the AI dashboard and
marketing elements are outside this product. Lazyweb did not expose a desktop
Spotlight result-ranking study, so no unsupported claim is derived from it.

Reference: <https://www.lazyweb.com/canvas/flows/raycast/ask-ai-and-switch>

## Interaction

- Default shortcut is configurable; opening always clears transient errors.
- Search field owns focus immediately and preserves the current keyboard input
  source.
- Up/Down changes selection; Return executes primary action; Command-K opens
  actions; Escape closes actions first and then the palette.
- Command-Return reveals/open-containing-folder where applicable.
- Typing never requires selecting a provider or entering a prefix.
- Empty query favors recent/frequent items without noisy category headers.
- Pinned applications sort ahead of ordinary applications. Pin/unpin lives in
  the action menu; the settings screen owns bulk visibility selection.
- Web search is a normal low-priority result and runs only after Return.

## Layout

- Compact floating panel, visually calm and native, never a settings/marketing
  screen.
- Search field, result list, optional detail/preview area, and concise keyboard
  hints are the only persistent regions.
- Result rows use shared spacing, typography, color, radius, and icon tokens from
  `DropThingsDesignSystem`; do not introduce raw constants in module views.
- Highlight only the selected row. Provider type is secondary metadata, not a
  rainbow of category colors.
- Window size may adapt to result count but must not jump as asynchronous file
  results arrive.

## Result presentation

- Application: app icon, display name, optional path when ambiguity exists.
- File/folder: file icon/thumbnail, name, compact parent path, modification date
  only when relevant.
- Command/action: SF Symbol, action title, module/system subtitle.
- Calculation: expression and formatted answer with a clear “Copy result” cue.
- Loading is shown only for the provider still loading; never replace existing
  results with a global spinner.

## Accessibility

- Full keyboard operation with a visible selection and correct focus order.
- VoiceOver announces result type, title, subtitle, position, and primary action.
- Respect Reduce Motion, Increase Contrast, Reduce Transparency, and system text
  settings where AppKit/SwiftUI support them.
- Do not encode provider or state by color alone.

## Permission and privacy copy

The first release requests no TCC permission merely to open the palette. File
search explains that it uses the local Spotlight index and cannot see excluded
or inaccessible content. Usage history stays on the Mac. When web search is
enabled, only an explicitly executed query is encoded into an HTTPS URL and
given to the selected browser; merely typing never sends it.

## Workflow extension note — 2026-07-13

The existing Lazyweb-derived keyboard-first pattern was retained for recent and
pinned apps and for the optional web result. These additions use progressive
disclosure in the existing action menu and settings instead of adding a mode or
provider prefix.
