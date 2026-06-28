# Decisions

Use this file for durable architecture and product decisions.

## 2026-06-28: Native macOS App

Decision: build DropThings as a native Swift/SwiftUI/AppKit app.

Why:

- The core modules need macOS system APIs.
- Native settings, permissions, windows, drag/drop, and menu bar behavior matter.
- Electron/Tauri would add weight without helping the hardest parts.

Tradeoff:

- Some UI prototyping may be faster on the web, but production should remain native.

## 2026-06-28: Modular Core

Decision: each utility is a module registered with a small core.

Why:

- The app needs to grow over time.
- Modules require different permissions and lifecycle behavior.
- Clear boundaries make system-level code safer.

Tradeoff:

- More upfront structure than a single-purpose utility, but it prevents the app from becoming a pile of global callbacks.

## 2026-06-28: File Shelf Before Menu Bar Cleaner

Decision: implement File Shelf before Menu Bar Cleaner.

Why:

- It has high user value and lower platform fragility.
- Menu bar manipulation is more sensitive to macOS versions and permissions.

Tradeoff:

- The visually obvious “clean menu bar” feature arrives later, but the foundation will be stronger.

## 2026-06-28: macOS 14 Minimum Deployment Target

Decision: target macOS 14 (Sonoma) as the minimum version.

Why:

- `MenuBarExtra` (macOS 13) works on 13, but `showSettingsWindow:` is a 14+ selector and we want one Settings path, not two.
- `NavigationSplitView` styling we want is cleaner on 14+.
- Most active macOS users are on 14+ today.

Tradeoff:

- Drops support for Ventura (13). Acceptable: the project is brand new and not in users' hands.

## 2026-06-28: SwiftPM Libraries + Xcode App Target

Decision: implement Core / DesignSystem / Platform / Modules as SwiftPM library targets. The Xcode project owns only the macOS app bundle (Info.plist, entitlements, Assets, target settings) and consumes the libraries via a local package reference.

Why:

- SwiftPM gives us free parallel builds, clean module boundaries, and unit-test targets that compile on every CI runner that has Swift.
- The Xcode project only needs to manage things SwiftPM cannot (Info.plist, code signing, app entitlements).
- Library boundaries are the same boundaries documented in `AGENTS.md`, so the dependency graph enforces them.

Tradeoff:

- Two file hierarchies to keep in sync (Sources/ for SPM, App/ for Xcode).
- Tests run via `swift test` against the SPM targets, but the Xcode project does not have a test target in Phase 0. Add one when we need UI tests.

## 2026-06-28: App Sandbox Disabled for Phase 0

Decision: ship without the App Sandbox entitlement for now.

Why:

- File Shelf, Scroll Control, and Menu Bar Cleaner all need cross-app access that the sandbox restricts without expensive user prompts.
- Direct signed + notarized distribution is the documented distribution path for v1 anyway.

Tradeoff:

- Loses some Mac App Store compatibility. Already a non-goal per `product-plan.md`.
- Re-evaluate when we know which entitlements each module really needs.

## 2026-06-28: File Shelf v0 Drops Use `NSDraggingDestination`, Not SwiftUI `.onDrop`

Decision: the File Shelf drop target lives on an `NSView` subclass that overrides `draggingEntered` / `performDragOperation`, and the SwiftUI list is hosted inside that view via `NSHostingView`.

Why:

- `.onDrop` does not expose `NSPasteboard` directly; it gives `[NSItemProvider]`, which forces every drop to async-load by UTI. That makes the `PasteboardItemReader` harder to share with unit tests (NSPasteboard-only fixtures) and hides the actual pasteboard contents from us.
- `NSDraggingDestination` is the same primitive Finder uses, so behavior matches user expectations across Spaces and fullscreen.
- Per `docs/architecture.md` the platform adapter `DraggingShelfWindow` was always meant to live in `DropThingsPlatform`, not in a SwiftUI modifier.

Tradeoff:

- We host SwiftUI inside an AppKit view. Layout, hit-testing, and focus all route through AppKit first. Costs a bit of indirection but keeps drop logic testable and reuses the existing adapter shape.

## 2026-06-28: File Shelf State Lives In Memory For v0

Decision: shelf items are not persisted across launches yet. Pinned items (a future feature) will be persisted with security-scoped bookmarks once we know the bookmark shape we actually need.

Why:

- Phase 1 v0 is a vertical slice: drop, see items, remove, clear. No use case forces persistence yet.
- Persisting file URLs without bookmarks is misleading (the URL becomes invalid on the next launch when sandboxed, and is unreliable even without it). Better to wait until we have the sandbox story pinned down.

Tradeoff:

- Restarting the app loses the shelf. Acceptable because we are explicit about it in the docs and the "Clear shelf when disabled" toggle is the only related user-visible choice for now.

## 2026-06-28: Show Shelf Hotkey Uses Carbon `RegisterEventHotKey`, Default ⌥⌘S

Decision: summon the File Shelf with ⌥⌘S via Carbon's `RegisterEventHotKey`, wrapped in a `GlobalHotkey` adapter inside `DropThingsPlatform/Adapters/`. The adapter also adds a MenuBarExtra entry as a fallback for users who do not know the shortcut.

Why:

- `RegisterEventHotKey` works even when DropThings is not focused — that is the point of a global hotkey. `NSEvent.addGlobalMonitorForEvents` only observes (does not intercept cleanly) and requires Accessibility permission. SwiftUI's `.keyboardShortcut` on a `MenuBarExtra` only works while the menu is open.
- Carbon is already implicitly linked by AppKit. We do not pull in a third-party hotkey library.
- If ⌥⌘S is already owned by another app, `RegisterEventHotKey` returns a non-zero `OSStatus` and we surface the module as `.degraded` with a message instead of crashing. The MenuBarExtra entry remains usable.

Tradeoff:

- Carbon is a C API and the `EventHandlerRef` / `EventHotKeyRef` references need careful lifecycle handling. We pin them in `GlobalHotkey` and clean them up in `unregister()` plus the deinit defensive guard.
- Hotkey customization (letting the user rebind) is a future feature. v0 ships a fixed default.

## 2026-06-28: DropThingsModule Protocol Is `@MainActor`

Decision: the `DropThingsModule` protocol is annotated `@MainActor`. Every conforming type runs on the main actor.

Why:

- Modules touch AppKit, SwiftUI, and CoreGraphics event taps. Making the isolation explicit at the protocol level removes the need for `@preconcurrency import` per conformer and eliminates a class of "called from wrong context" crashes.
- The registry is already `@MainActor`. A protocol-level `@MainActor` keeps every `module.start()` / `module.stop()` / `module.state` access correctly typed.
- After File Shelf, both real modules (and the fake one) sit on `@MainActor`. The protocol now matches reality instead of leaving each conformer to invent its own concurrency story.

Tradeoff:

- Future modules that genuinely need off-main work (e.g. heavy parsing) will have to `Task.detached` explicitly. That is the right shape anyway: do work off-main, surface results on-main.

## 2026-06-28: Scroll Control Classifies Devices From Event Phase, Not IOKit

Decision: `ScrollEventTransformer.classify` decides trackpad / Magic Mouse / mouse wheel by reading `scrollPhase` and `momentumPhase` fields on the incoming `CGEvent`. It does not consult IOKit HID device trees.

Why:

- IOKit introspection requires reaching into private HID APIs and depending on the user's hardware layout (USB vs Bluetooth, multiple docks, external Magic Keyboards with trackpads). That complexity is not justified for v0.
- The phase heuristic is what apps like Scroll Reverser and UnnaturalScrollWheels have used for years. Trackpads and Magic Mouse report non-zero phase during gestures and momentum; mouse wheels never do.
- A pure function on event fields is fully unit-testable (16 tests in `ScrollEventTransformerTests`).

Tradeoff:

- Edge cases (Apple Silicon desktops with a Magic Trackpad plugged in) classify as "trackpad" by the heuristic. That is the same behavior the user wants (natural scrolling on a Magic Trackpad is correct).
- If a future device breaks the heuristic we add a manual override in settings rather than deepening IOKit usage.

## 2026-06-28: Scroll Event Tap Runs On The Main Run Loop, Not A Dedicated Thread

Decision: `EventTapClient` registers the tap's run-loop source on `CFRunLoopGetMain()`. The transformer is invoked synchronously on the main thread.

Why:

- CGEventTap callbacks are documented to fire on the run loop that owns the tap. Using the main run loop is the path every reference implementation uses.
- Our transformer is sub-microsecond (a couple of arithmetic ops and an optional object allocation). There is no reason to pay the cost of context switching to keep it off main.
- macOS kills a tap that takes longer than a few hundred milliseconds. Running on main keeps that budget honest because any UI hang also stalls the tap — visible immediately during manual checks.

Tradeoff:

- A future module that needs heavier per-event processing would still need to do it off-main and re-dispatch the result. We are not that module today.

## 2026-06-28: Menu Bar Cleaner v0 Hides Via `kAXVisibleAttribute`

Decision: `MenuBarController` toggles each menu bar extra by setting `kAXVisibleAttribute` to `kCFBooleanFalse` on the AXUIElement that `kAXMenuBarExtrasAttribute` returns for the system-wide element.

Why:

- The Accessibility API is the only public way to enumerate the menu bar extras. AppleScript via System Events is the alternative, but it is slower, less precise, and requires `osascript` to be available.
- `kAXVisibleAttribute` is documented and supported. macOS Sonoma and later accept writes through it for almost every extra we tested (Wi-Fi, Battery, Spotlight, third-party status items).
- We identify items by `bundleId:title`. The bundle identifier gives us a stable id across launches even when the order in the bar changes.

Tradeoff:

- macOS does not notify us when the menu bar composition changes. The user must click **Refresh menu bar** in settings after installing or removing apps. A future version can subscribe to `NSWorkspace.didLaunchApplicationNotification` and refresh automatically.
- Some system items (Control Center, the clock) are not movable. We do not yet filter them out; the user can still toggle them, and we report the failure as `kAXErrorFailure` if it happens.
- For a true "Overflow" pattern (Ice / Bartender style) we would also need a separator `NSStatusItem` and a reveal-all action. Those are deferred to v1.

## 2026-06-28: Menu Bar Identifier Is `bundleId:title`, Not Just The Title

Decision: each `MenuBarItem.id` is derived from the owning process's bundle identifier plus the item title. Bundle id alone is not unique (systemUIServer owns many items).

Why:

- Bundle id is stable across launches. The title is the human label. Together they uniquely identify a specific extra even when several come from the same process.
- If bundle id is unavailable (rare for extras, but possible) we fall back to `pid:title`. Pids change every launch, so the user's choice for those items would not survive a restart. We surface that the item has an unstable id in a follow-up.

Tradeoff:

- If an app changes the title of its extra in a release (rare), the user's "hide" choice does not carry over. Acceptable: the worst case is the item becomes visible again and the user re-hides it. We document this in the manual checklist.

## 2026-06-28: Manual NSWindow For Settings, Not SwiftUI `Settings`

Decision: `DropThingsApp` no longer declares a SwiftUI `Settings` scene. The settings window is a plain `NSWindow` owned by `SettingsWindowController`.

Why:

- SwiftUI's `Settings` scene races with `setActivationPolicy(.accessory)`. macOS sometimes opens the window invisibly, refuses the `showSettingsWindow:` selector, or opens it off-screen. The race is hard to reproduce and hard to debug.
- A manually-owned `NSWindow` gives us `makeKeyAndOrderFront` + `NSApp.activate(ignoringOtherApps: true)` in the right order every time. We control visibility, restoration, and activation without trusting opaque SwiftUI machinery.
- The cost is roughly thirty lines of AppKit glue, contained in one file. We avoid a brittle platform integration for the most-clicked button in the app.

Tradeoff:

- We lose SwiftUI's automatic scene-restoration. We compensate with `isReleasedWhenClosed = false` so the window instance survives close, and we explicitly call `window.makeKeyAndOrderFront` on `show()`.
- Future app-level windows (e.g. a per-module log viewer) should follow the same manual pattern; the `Settings` scene is the only place we used to rely on it.

## 2026-06-28: Accessibility Prompt Is Triggered Explicitly, Not Implicitly

Decision: when the user wants Accessibility or Screen Recording, the app calls `AXIsProcessTrustedWithOptions({prompt: true})` (and `CGRequestScreenCaptureAccess` for screen recording) instead of only opening System Settings.

Why:

- A common first-run failure mode was: user clicks "Open Settings" → System Settings opens, but DropThings is not in the Accessibility list. macOS only adds an app to the list after it tries to use the API.
- The Accessibility and Screen Recording entitlements both require the app to **request** access via the explicit prompt APIs. Opening the System Settings pane alone does not register the app.
- We expose the prompt as a `Request Access` button next to `Open Settings…` so the user understands the difference. macOS shows a system dialog the first time; subsequent calls are no-ops until the user re-grants.

Tradeoff:

- The first click on `Request Access` triggers a system dialog the user did not see before. We mitigate with the in-app explanation that the prompt is the only way to register DropThings.

## 2026-06-28: File Shelf Pinned Items Live In App Support, JSON

Decision: pinned File Shelf items are serialized as JSON in `~/Library/Application Support/app.dropthings/file-shelf-pinned.json`.

Why:

- DropThings is non-sandboxed (`com.apple.security.app-sandbox = false`). File URLs survive across launches; we do not need security-scoped bookmarks.
- App Support is the canonical macOS location for app-owned data that should survive app updates and not appear in iCloud or Time Machine backups automatically. The user can inspect, copy, or wipe the file without touching the app.
- JSON is human-readable and matches the rest of our persistence story (`ScrollSettings`, `FileShelfSettings`, `MenuBarCleanerSettings`).

Tradeoff:

- If we ever ship a sandboxed build (App Store, future), we will need to migrate to security-scoped bookmarks. The `ShelfPersistence` class is the single seam for that change.
- Manual editing of the file while DropThings is running is not protected. Acceptable for a developer-friendly app; a future version can write to a temp file and rename atomically (already the case via `Data.write(to:options: .atomic)`).

## 2026-06-28: Settings Export Uses `defaults` CLI, Not a Custom Format

Decision: import and export go through the macOS `defaults` command, producing a standard property-list file.

Why:

- `defaults export <suite> <file>` produces a file the user can read with `defaults read` or open in Property List Editor. It is the format the system itself uses.
- Round-tripping through our own JSON would add a translation step and a place for bugs (e.g. types that do not survive JSON cleanly, like `Data`).
- A user who has never used DropThings can read the exported file and understand every key — `core.modules.enabled`, `modules.file-shelf.maxItems`, etc. — because the keys are explicit and namespaced.

Tradeoff:

- The exported file is plist, not JSON. We document this in the export dialog (`Save As` defaults to `*.plist`) and in `docs/manual-checks.md`.

## 2026-06-28: First-Run Onboarding Is A Standalone Window, Not A Settings Tab

Decision: `OnboardingWindowController` opens a small standalone window the first time DropThings launches, separate from the Settings window.

Why:

- The Settings window is for adjusting preferences. Onboarding is a one-time orientation that ends with a "Skip" or "Continue" button. Different lifetime, different purpose, different window.
- A sheet or modal on Settings would block the user from looking at the sidebar while reading the welcome copy.
- The window is shown once and dismissed. The completion flag lives in `UserDefaults` under a separate key (`app.dropthings.onboarding.completed`) so a user can re-trigger it via `defaults delete app.dropthings.onboarding.completed` if they want to see it again.

Tradeoff:

- One more window to maintain. Worth it because the first-run experience is the highest-leverage screen in the app — it sets the tone for the user's relationship with permissions and modules.

## 2026-06-28: Keep Awake Owns One IOPMAssertion At A Time

Decision: `KeepAwakeAssertion` holds at most one `IOPMAssertion`. The module chooses between `PreventUserIdleSystemSleep` and `PreventUserIdleDisplaySleep` and releases the old one before acquiring the new.

Why:

- macOS allows multiple simultaneous assertions, but the cumulative effect is hard to reason about. One assertion, one reason, one name is enough for the user-facing toggle.
- The two reasons are the only ones we need. `NoIdleSleepAssertion` is deprecated; `NetworkClientActive` is for power-hungry networking; we do not use them.
- The assertion name embeds `DropThings` so `pmset -g assertions` shows the owner and the user can find it.

Tradeoff:

- If we later want a "only when on AC power" mode, we would add a second assertion gated on `IOPSCopyPowerSourcesInfo`. v0 keeps the single-assertion model so the code stays small.

## 2026-06-28: Color Picker Uses A Frozen Full-Screen Overlay

Decision: when picking, the Color Picker module shows a borderless, top-most `NSPanel` that draws the captured screen at 35% opacity plus a crosshair. A click anywhere on that panel samples the captured pixel at that location.

Why:

- The user's mental model is "the screen freezes so I can click on the color I want". Drawing the captured screen behind the panel makes the panel non-destructive — clicking feels like clicking on the real desktop.
- A separate `NSPanel` with `level = .screenSaver` floats above every other window. We do not need a global event monitor or Accessibility permission to receive clicks.
- The crosshair is drawn in the panel's `draw(_:)` from `NSEvent.mouseLocation`. No tracking area, no delegate, no race conditions.

Tradeoff:

- The panel blocks the user from interacting with other apps while picking. ESC cancels, click samples. We do not support "magnifier preview" yet — that lands in v1 with a sub-region CGImage and a draw-cycle update.
- The captured screen is the state at the moment the user pressed ⌥⌘C. If the desktop content changes mid-pick (a notification appears), the change is invisible until the user picks again.

## 2026-06-28: Screenshot Save Path Is `~/Downloads/Screenshots`

Decision: by default, screenshots land at `~/Downloads/Screenshots/DropThings-<ISO8601 timestamp>.png`. The user can override the destination later via a folder picker.

Why:

- `~/Downloads` is the macOS convention for "things the user explicitly produced and wants to find". Inside it, `Screenshots` matches what the system "Screenshot" app and `screencapture` use.
- We avoid `~/Library/Application Support` for screenshots because that location is invisible to Finder and confusing for users.

Tradeoff:

- A future version will let the user pick a different folder, with a security-scoped bookmark so the choice survives sandboxing. We persist `lastSavePath` in the settings so we can show "last saved here" copy in the UI; the folder picker itself is v1.

## 2026-06-28: Screenshot Annotations Are v2

Decision: the v0 Screenshot module ships without annotations. v1 will add rectangles, arrows, freehand, and text. v2 will add a color picker (re-using `ColorPickerModule`'s picking UI) and exports to PNG / JPEG / clipboard with annotations baked in.

Why:

- Annotations are a large surface area (tool selection, undo, color palette, layer order, export). Doing them in v0 alongside capture would push the module past the point where it can be reviewed in one sitting.
- The capture-and-save flow alone already solves the user's stated problem ("dibuja, rectángulos, escribir" — they will get there in v2).
- The Color Picker module will become the color source for the annotation palette, so v0 cleanly unblocks v2.

## 2026-06-28: Hotkeys Are User-Editable, Not Hardcoded

Decision: every hotkey is stored as a `GlobalHotkey.Definition` in the module's settings (Codable, persisted as JSON). The Settings UI shows a `ShortcutRecorder` that lets the user press a new combo to rebind the action. Carbon `RegisterEventHotKey` failure flips the module to `.degraded` with a message naming the shortcut and suggesting the menu bar / button as a fallback.

Why:

- The original ⌥⌘S / ⌥⌘C / ⌘⇧4 defaults collide with system or third-party shortcuts (PowerToys, CleanShot, Shottr, screenshot tools, design apps). Hardcoded bindings guarantee a subset of users gets a degraded experience.
- The `ShortcutRecorder` uses `NSEvent.addLocalMonitorForEvents(.keyDown)` so we never need Accessibility for the recorder itself. We require at least one modifier (Cmd / Option / Ctrl / Shift) and reject ESC + bare keys.
- Migrating persisted settings is explicit via `init(from decoder:)` with `decodeIfPresent` for the new `hotkey` field. Users with pre-hotkey settings keep their old values and get the default hotkey on top.

Tradeoff:

- A future version may want per-module "preset" shortcuts (designer, gamer, etc.). The current `ShortcutRecorder` is a single recorder; presets would be a P2.

## 2026-06-28: Color Picker Overlay Spans Every Connected Display

Decision: `ColorPickerOverlayWindow.unionFrame()` returns the bounding box of every `NSScreen.frame` instead of `NSScreen.main.frame`. The window covers the entire union so the user can pick a pixel on any monitor.

Why:

- The old code only covered the main display. The audit flagged this as a documented-but-broken behavior ("Click en monitor primario y secundario copia el color correcto").
- `NSScreen.screens` already returns full-frame coordinates, so the union is a simple `min/max` reduction. No multi-screen math needed at runtime.
- The crosshair continues to be drawn from `NSEvent.mouseLocation`, which is also in the same coordinate space.

Tradeoff:

- A single full-screen window uses more GPU than one per screen. For the short window the picker is open, this is negligible.
- A click on the seam between displays samples the pixel that belongs to whichever display owns that coordinate at the OS level. That matches the user's expectation.

## 2026-06-28: Screenshot Save Folder Uses A Security-Scoped Bookmark

Decision: `ScreenshotSettings.saveFolderBookmark` stores an `NSURL.bookmarkData(.withSecurityScope)` created from the folder the user picks in `NSOpenPanel`. On every save, the bookmark is resolved; if it fails we fall back to `~/Downloads/Screenshots`.

Why:

- DropThings is currently non-sandboxed so the bookmark is technically unnecessary today. We add it now because the moment we ship a sandboxed build (App Store, future Mac App Store), saving outside `~/Library/Containers/<bundle>` becomes impossible without a bookmark.
- The code path is identical for non-sandboxed and sandboxed apps: `URL(resolvingBookmarkData:)` returns the URL either way, and `startAccessingSecurityScopedResource` is a no-op when there is no scope.
- If the bookmark ever resolves stale (user moved or renamed the folder), we fall back to the default directory. No crash.

Tradeoff:

- The NSOpenPanel that lets the user pick the folder is a macOS-native flow that looks slightly heavier than a "type a path" text field. Acceptable because folder picking is rare (once per session, usually).
- A user who denies the bookmark scope silently loses the override. We log a warning and fall back; we do not block saves.

