# Decisions

Architecture and product decisions, newest first. Each entry: date,
context, decision, consequences. Superseded entries stay in place with a
`Superseded by` line so the history is readable.

## 2026-07-13 — Markdown editing follows native document commands

Context: editor changes were published on a later main-queue turn. Saving
immediately after typing could therefore write the previous buffer, and the
standalone utility window had no standard file shortcuts or dirty-window close
protection. Finder selection errors were swallowed and the app lacked the
Automation usage declaration required for a reliable permission prompt.

Decision: `NSTextView` publishes each delegate change synchronously to its
document. The viewer provides ⌘O, ⌘S, ⇧⌘S, ⌘W, and ⇧⌘W; its native window
delegate resolves every dirty tab before closing. Open, drop, Finder selection,
and Save As share one Markdown extension policy. Finder AppleScript errors are
shown in the module, and `NSAppleEventsUsageDescription` explains the opt-in
Automation feature.

Consequences: saving cannot race the final edit, closing cannot silently lose
work, non-Markdown text files no longer enter through the open panel, and a
denied Finder permission has an actionable visible state. The core viewer
still needs no permission; Automation remains opt-in.

## 2026-07-13 — Markdown Viewer: tabs and opt-in Finder selection

Context: the first cut opened one document at a time and the hotkey always
opened an empty viewer, so the user had to use Open… even when a `.md` was
already selected in Finder. The user also wanted several files open at once
and a way to switch between them.

Decision: the module now owns `[MarkdownDocument]` with an active index; the
window shows one tab per document (`+` / ⌘T to add, `x` to close, ⌘1…⌘9 to
switch, click to select). `NSOpenPanel` and drag-and-drop accept multiple
files and open each as a tab; reopening a file that is already open focuses
its tab instead of duplicating. Closing the last tab leaves an untitled tab
so the window never goes empty; closing a dirty tab prompts save / discard /
cancel. A second, opt-in behavior — "Open the Finder selection with the
shortcut" (default off) — reads Finder's selection via AppleScript when the
hotkey fires with Finder in front, and opens the selected `.md` file(s) as
tabs. Reading Finder's selection sends an Apple Event to Finder, which
triggers macOS' Automation permission prompt the first time.

Consequences: the core module keeps `requiredPermissions = []`; the
Finder-integration is a progressive enhancement gated behind a setting with
an explanatory caption, so the basic viewer stays permission-free and
seamless across ad-hoc reinstalls. Users who enable it accept the Automation
prompt (and, on ad-hoc builds, re-grant it after each reinstall, the same
ad-hoc tax Scroll Control pays for Accessibility). The pure helpers
(`FinderSelectionReader.parsePaths` / `markdownOnly`) are `nonisolated` so
the filtering logic is unit-tested without AppleScript.

## 2026-07-13 — Markdown Viewer renders via WKWebView + vendored JS

Context: a new module must read AND edit Markdown files with a 100%-
complete GFM preview (tables, fenced code with syntax highlighting,
task lists, images, strikethrough). Apple's `AttributedString(markdown:)`
covers CommonMark but not tables or code highlighting, so it is
insufficient. Adding the project's first external SwiftPM dependency
(swift-markdown-ui, cmark-gfm wrapper) would break the zero-dependency
stance without a separate architecture decision.

Decision: the preview is a `WKWebView` that loads an HTML shell
containing vendored `marked.min.js` (MIT, v12.0.2) and
`highlight.min.js` (BSD-3-Clause, v11.9.0) bundled as SwiftPM resources
under `MarkdownViewer/Resources/`. The editor is a plain `NSTextView`
in an `NSViewRepresentable`. Markdown edits are pushed from Swift to JS
via `evaluateJavaScript` so the webview never reloads while typing. The
window supports split / editor-only / preview-only layouts. File access
comes from `NSOpenPanel` or drag-and-drop, so `requiredPermissions = []`
and no security-scoped bookmarks are persisted. Licenses are compatible
and tracked in `docs/research/open-source-references.md`; both JS files
and their LICENSEs are vendored as-is.

Consequences: the module ships with zero SwiftPM dependencies and no TCC
permission. Full GFM rendering is delegated to two well-maintained JS
libraries whose source lives in the repo and can be audited. The cost is
a `WKWebView` per preview instance and ~157 KB of vendored JS. External
links open in the default browser via the navigation delegate. Theme
(light/dark/auto) and font size are applied via CSS variables and a
`data-theme` attribute, with a KVO observer on `NSApp.effectiveAppearance`
for live theme switching.

## 2026-07-12 — Clipboard history is durable, local, and bounded

Context: only pinned text/file entries lived in UserDefaults. Normal history
and raw images disappeared on every app restart, there was no age policy, and
Clipboard's optional auto-paste could unexpectedly request Accessibility.

Decision: all history is persisted under Application Support with an atomic
JSON index and PNG image assets. Defaults are 200 items, 30 days for unpinned
entries, and 250 MB for raw image assets; pinned/favorite entries do not expire.
Enter copies by default. Auto-paste uses Accessibility only if it is already
granted and never requests it from Clipboard History.

Consequences: replacing or updating the `.app` preserves history, disk usage is
visible and bounded, sensitive transient/concealed types remain ignored, and
Accessibility remains a Scroll Control-only permission boundary.

## 2026-07-12 — Awake sessions expire; scroll changes apply live

Context: Keep Awake always prevented both system and display sleep indefinitely.
Scroll Control rebuilt its event tap on every settings change, pause accidentally
became a persistent "start paused" preference, and the bundle-ID field created an
override for every partial keystroke.

Decision: Keep Awake defaults to system sleep prevention only, with optional
display assertion and fixed-duration sessions that retain their absolute end
date across relaunches. Scroll Control keeps one event tap and swaps its pure
transformer settings live; temporary pause and start-paused are separate, and
per-app overrides commit only complete bundle IDs.

Consequences: Keep Awake uses less battery by default and timed sessions cannot
silently become permanent. Scroll tuning no longer interrupts input while a
slider moves and per-app settings no longer accumulate malformed entries.

## 2026-07-12 — Ship five maintained utilities and explain permissions first

Context: the app exposed eleven modules with uneven reliability, a dense
settings hierarchy, and permission state that forgot prior rejection whenever
a module was enabled. Users could not tell whether a utility was waiting,
denied, or actually running.

Decision: the composition root and SwiftPM shipping target now contain File
Shelf, Clipboard History, Color Picker, Scroll Control, and Keep Awake only.
The control center is the first-run surface. Enabling a gated module opens an
in-app explanation before the native macOS request; canceling the initial flow
rolls enablement back, while an existing blocked module remains enabled and
auto-recovers after access is granted. Enabling never resets prompted state.

UI follows Apple's current layering: system split-view navigation, standard
materials in the content layer, SF Symbols, system controls, and sparse health
indicators. Custom glass effects are intentionally avoided.

Consequences: Accessibility is the only TCC permission in the shipping
product, used only by Scroll Control. Retired source remains excluded rather
than deleted until a separate cleanup decision.

## 2026-07-12 — Visual content uses native sampling and Quick Look

Context: Color Picker rebuilt a SwiftUI loupe at 60 Hz on the main actor,
making the cursor feel frozen. Clipboard History and File Shelf reduced most
files to names/icons even when macOS could render the content directly.

Decision: Color Picker delegates the live magnifier entirely to
`NSColorSampler` and only shows a short copied-color confirmation after the
click. It writes both `NSColor` and formatted text to the pasteboard. Platform
owns shared file classification, Quick Look previews, and asynchronous Quick
Look thumbnails; Clipboard History and File Shelf consume those adapters.

Consequences: sampling no longer polls or captures the screen, copied colors
render as colors in history, and images/videos/documents/folders gain native
previews without format-specific code in either module.

## 2026-07-12 — Carbon handlers pass unmatched shortcuts down the chain

Context: each module installed a handler on the Carbon dispatcher. The newest
handler returned `noErr` even when an event ID belonged to another module, so
it swallowed older modules' shortcuts while every registration still reported
success.

Decision: `GlobalHotkey` validates the DropThings signature and expected ID;
unmatched events return `eventNotHandledErr` so Carbon continues through the
handler chain.

Consequences: multiple enabled modules can receive their shortcuts
simultaneously. Routing and shipped chord uniqueness are regression-tested.

## 2026-07-12 — Reliability pass: observable state, hotkey health, and coordinates

Context: modules could fail after `start()` without the registry noticing;
several modules overwrote shortcut failures with `running`; shipped defaults
contained a collision; AppKit and AX/Core Graphics rectangles were mixed.

Decision: `DropThingsModule` is observable and `ModuleRegistry` mirrors every
state transition. `HotkeyRegistrationHealth` owns recoverable shortcut errors,
default chords are uniqueness-tested, and the legacy Snippets default migrates
from `⌃⌥S` to `⌃⌥N`. `ScreenCoordinateMapper` is the single coordinate boundary
for WindowSnap, Screenshot Region, and the Color Picker loupe.

Consequences: late failures and permission revocation reach the UI, a broken
shortcut does not disable healthy fallback actions, and windows/captures use
the correct display coordinate space.

## 2026-07-12 — Menu Bar Cleaner keeps one overflow divider

Supersedes the 2026-07-02 claim that additional dividers can be overflow edges
and the 2026-06-28 always-visible bundle-ID hint list.

Context: multiple giant overflow dividers can push the wrong items away, and
an always-visible bundle list cannot be enforced by the divider technique.

Decision: settings sanitize exactly one main overflow divider. Additional
dividers are visual separators. Collapse validates chevron/divider order, uses
at least twice the widest display width, and does not persist transient hover
reveal. Safe reset returns to one revealed main divider.

Consequences: invalid layouts degrade with recovery guidance instead of hiding
the wrong side, and the UI no longer promises per-app icon control.

## 2026-07-12 — Settings use the app domain and imports relaunch atomically

Context: constructing a named `UserDefaults` suite with the process's own
bundle ID emits a macOS warning and did not persist reliably. The old importer
called `defaults import` while modules held cached settings.

Decision: production uses `UserDefaults.standard` when the requested name
equals `Bundle.main.bundleIdentifier`. Import replaces the persistent domain
in-process and relaunches the app.

Consequences: toggles survive restart and all modules observe one imported
snapshot rather than a mix of old and new preferences.

## 2026-07-02 — Menu Bar Cleaner: overflow drawer and named dividers

Context: the existing divider-only overflow was hard to discover and the
settings screen was confusing. Users expected a Windows-style overflow
drawer and the ability to create visual groups.

Decision: `MenuBarCleanerModule` now supports two interaction modes. In
"toggle collapse" mode the chevron behaves as before. In "overflow drawer"
mode the chevron opens a compact floating panel with state, one-tap
collapse/reveal, profile chips, and quick settings. Settings also expose
named dividers: the main divider is an overflow divider that hides icons
to its left; additional dividers are visual separators. All divider state
lives in `MenuBarCleanerSettings` with backward-
compatible decoding.

Consequences: no Accessibility permission is needed. The drawer is a plain
NSPanel owned by the module, so it cannot show other apps' icons, but it
surfaces DropThings' own controls clearly. Divider autosave names are keyed
by UUID so extras survive relaunch.

## 2026-07-02 — Menu Bar Extra shows active module icons

Context: the menu bar menu exposed Export/Import Settings, which felt like
settings internals, and it did not reflect which modules were running.

Decision: the DropThings menu bar menu now lists every active module. Each
row shows the module name and icon; modules with a `primaryAction` run that
action on click, and modules without one open their settings pane. The
global File Shelf shortcut and Export/Import entries were removed from the
menu bar surface; settings import/export stays available inside Settings.

Consequences: the menu bar surface is task-oriented. Modules opt in via the
new `ModulePrimaryAction` value; the registry requires no per-module
knowledge. Opening settings to a specific module writes two `@AppStorage`
keys and shows the existing settings window.

## 2026-07-02 — File Shelf: collections as the source of truth

Context: the shelf stored a single flat `[FileShelfItem]`. Users juggling
many files had no way to group them, and drops from different tasks
intermingled.

Decision: `collections: [ShelfCollection]` is the source of truth on
`FileShelfModule`; `items` is a computed view over the active collection.
All item mutations route through `mutateActiveItems` so they always land
in the right tab. On-disk persistence moved from a flat `items` blob to a
`collections` blob with a backward-compatible migration: legacy pinned
items fold into a single default "Shelf" collection.

Consequences: adding/removing/renaming tabs is cheap; selection is
cleared on tab switch to avoid cross-tab surprises. `FileShelfItem` and
the merge/trim helpers are unchanged, so existing ingest semantics
(dedup by id, trim unpinned first) carry over verbatim.

## 2026-07-02 — File Shelf: browser drops download to disk

Context: dragging an image from a browser previously surfaced as a URL
or raw text — there was no file to drag onward into other apps.

Decision: a `ShelfIngestCoordinator` resolves each pasteboard candidate
into a `FileShelfItemKind`. Raw image bytes are saved via `ImageSaver`,
and web URLs are downloaded via `WebItemDownloader`, both writing into
`~/Downloads/Dropthings/` with collision-safe naming. Failures surface as
`ingestError` (an `InlineAlert` in the shelf), never silently.

Consequences: a browser drag becomes a real file that can be re-dragged
anywhere. The coordinator is pure logic over an injected
`WebItemDownloading`/`ImageSaverProtocol`, so it is fully unit-testable
with fakes. `PasteboardItemReader` grew a richer `candidates(from:)`
return type alongside the legacy `read(from:)`.

## 2026-07-02 — File Shelf: shake rewritten with dominant axis; flick added

Context: the original `ShakeDetector` looked only at the X axis, so a
natural diagonal or vertical shake did not register — the gesture felt
random. There was also no reliable alternative trigger.

Decision: `ShakeDetector` now picks the dominant axis of motion and
counts reversals there, using per-step velocity (not raw displacement)
so detection is independent of sample timing. Sensitivity (Low/Medium/High)
maps to concrete thresholds. A new `FlickDetector` fires when the cursor
reaches the top of a screen having moved up fast; the shelf then drops
from the notch/menu bar with a slide animation (`showPanelFromNotch`).
Both detectors are fed by the single existing `MousePositionMonitor`
polling `NSEvent.mouseLocation` — no new permissions.

Consequences: any orientation of shake works; users who found shake
unreliable can use flick-to-notch instead. A shared cooldown
(`gestureCooldown`) prevents a single motion from double-triggering.

## 2026-06-28 — KeepAwake holds both sleep and display assertions

Context: the module originally aimed to hold a single
`PreventUserIdleSystemSleep` assertion. In practice the user's mental
model is "the Mac does not dim or sleep," which requires the display
assertion too.

Decision: `KeepAwakeAssertion.acquireKeepAwakeAssertions` acquires both
`PreventUserIdleSystemSleep` and `PreventUserIdleDisplaySleep`. The
module exposes `activeAssertionIDs` so diagnostics can show what is
held.

Consequences: two assertions released on `stop()`; `isAssertionActive`
is true only when both are held. Documented in
`Sources/DropThingsModules/KeepAwake/KeepAwakeModule.swift` and
`Sources/DropThingsPlatform/Adapters/KeepAwakeAssertion.swift`.

## 2026-06-28 — KeepAwake does not flip `enabled` on stop()

Context: `stop()` runs on app quit and on module disable. The previous
code set `settings.enabled = false` and persisted, so reopening the app
left KeepAwake off even if the user had it on.

Decision: `stop()` only releases the assertion and sets `state = .off`.
The persisted `enabled` flag is untouched on quit or module disable.

Consequences: quitting or temporarily disabling the module releases its power
assertions; re-enabling or relaunching restores the last internal choice.

## 2026-06-28 — Onboarding flag lives in `SettingsStore`, not `UserDefaults.standard`

Context: the onboarding completion flag was stored on
`UserDefaults.standard` while every other setting lives on the
`app.dropthings` suite. `SettingsImporter` walks the suite, so the flag
was never exported/imported.

Decision: the flag moves to `SettingsKey("app.onboarding.completed")`
on the `app.dropthings` suite. `OnboardingWindowController` takes a
`SettingsStore` in its init.

Consequences: import/export now carries the onboarding state. No
behavioral change for first-run users.

## 2026-06-28 — Migration version only advances on full success

Context: `SettingsStore.migrateIfNeeded()` logged a failed migration
but still advanced the schema to `currentSchemaVersion`, so the next
launch skipped the failed step and the user was left with a
half-migrated store.

Decision: the schema version advances one step at a time, only after
each migration completes. A throw stops the loop and leaves the store
at the last good version; the next launch retries from there.

Consequences: no migrations are registered today, but the first real
one will be safe. `currentSchemaVersion` is now `let`, not `var`.

## 2026-06-28 — Hotkey re-binding recovers from `.degraded`

Context: `FileShelfModule`, `ColorPickerModule`, and
`ScrollControlModule` only re-registered a hotkey after a settings
change if `state == .running`. A module stuck in `.degraded` from a
hotkey conflict could not recover by picking a new combo — the user
had to disable and re-enable the module.

Decision: the gate is now `ModuleState.isStarted` (helper in
`Sources/DropThingsCore/ModuleState.swift`), which is true for
`.starting`, `.running`, `.unavailable`, `.degraded`, `.failed` and
false only for `.off` and `.needsPermission`. Re-binding a hotkey
while degraded retries the registration.

Consequences: the user can recover from a conflict in-place. The
registry still owns the canonical state; modules just use the helper
to decide when to touch the global hotkey registry.

## 2026-06-28 — Carbon and NSEvent modifier flags translate at the boundary

Context: `GlobalHotkey` uses Carbon `RegisterEventHotKey`, which
expects Carbon modifier bits (`cmdKey = 1 << 8`, etc.). The defaults
used Carbon flags correctly, but `ShortcutRecorder` stored raw
`NSEvent.ModifierFlags.rawValue` (`.command = 1 << 20`, etc.), so
user-recorded shortcuts registered but never fired. `displayString`
had the inverse bug: it interpreted Carbon flags as NSEvent flags, so
the defaults rendered without their modifiers.

Decision: `GlobalHotkey.Definition.nsModifiers` and
`carbonModifiers(from:)` translate at the boundary. `ShortcutRecorder`
records via `carbonModifiers(from:)`. `displayString` and
`hasModifier` read via `nsModifiers`. Both directions are unit-tested in
`Tests/DropThingsModulesTests/Platform/GlobalHotkeyDefinitionTests.swift`.

Consequences: every shortcut the user records now works; the defaults
display correctly.

## 2026-06-28 — Color Picker uses the native `NSColorSampler`

Supersedes the 2026 frozen full-screen overlay approach (below).

Context: the original Color Picker built a custom full-screen overlay
to read pixels, which required Screen Recording permission. macOS
ships `NSColorSampler`, the native eyedropper used by system apps, which
needs no permission.

Decision: the module wraps `NSColorSampler`. The overlay and its
`PixelSampler`-based path were removed. `PixelSampler` stays in
Platform for future modules that genuinely need pixel reading.

Consequences: no Screen Recording permission for Color Picker. The
module has `requiredPermissions: []`. Less code, more native feel.

## 2026-06-28 — Menu Bar Cleaner uses divider overflow, not per-item AX

Supersedes the per-item `kAXVisibleAttribute` approach (below).

Context: toggling individual menu bar items via Accessibility was
fragile across macOS versions and required Accessibility permission for
a feature that should be light. Hidden Bar and Ice use a divider that
widens to push items off-screen — no per-item AX needed.

Decision: the module installs a wide `NSStatusItem` divider plus a
reveal chevron. Collapsing widens the divider to push left-of-divider
icons past the notch/screen edge; revealing shrinks it back.

Consequences: no Accessibility permission. Behavior is consistent
across macOS versions. The cost is no per-item reordering (planned for
a future Pro pass via `kAXPositionAttribute`).

## 2026-06-28 — Color Picker keeps `PixelSampler` for the live loupe

Superseded by 2026-07-12 — Visual content uses native sampling and Quick Look.

Context: the native `NSColorSampler` replaced the full-screen overlay,
so Screen Recording permission was removed. Phase B still wanted an 8x
loupe that follows the cursor while the sampler is open.

Decision: a new `ColorSamplerLoupe` adapter in Platform captures a small
region around the cursor via the `ScreenCapture` adapter and samples the
center pixel with the existing `PixelSampler`. A `ColorPickerLoupeWindowController`
in the module renders the feed through the shared `LoupeView` component.

Consequences: Color Picker still needs no Screen Recording permission.
The capture is read-only and visible only inside the app's own loupe
panel. `PixelSampler` is no longer "for future use" — it ships today.

## 2026-06-28 — Menu Bar Cleaner hover/profiles without Accessibility

Context: Phase B asked for hover-to-reveal, profiles, and an always-visible
list. The divider-overflow model cannot hide individual icons selectively,
but it can expand/contract the divider and remember per-profile state.

Decision: hover tracking is done with a small `HoverTrackingView`
attached to the chevron status-item button; profiles store only a
collapsed flag. Safe reset reveals the divider and removes extra separators.

Consequences: no Accessibility permission is required, and settings make no
unenforceable claim about keeping another app's status item visible.

## Historical — Color Picker frozen full-screen overlay

Superseded by the native `NSColorSampler` decision above. Kept for
context: the original implementation read pixels via `PixelSampler` and
required Screen Recording.
