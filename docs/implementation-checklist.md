# Implementation Checklist

> Phase 0–4 are complete. The app boots as a menu bar utility, ships a
> File Shelf, Scroll Control, and Menu Bar Cleaner, persists pinned items,
> imports / exports settings, runs a one-time welcome window, and is
> documented for release signing + notarization. See `docs/manual-checks.md`
> for the smoke walkthrough and `docs/RELEASE.md` for shipping.

## 1. Create The macOS Project — DONE

- [x] Create an Xcode macOS app project named `DropThings`.
- [x] Set deployment target (macOS 14.0 — see `docs/decisions.md`).
- [x] Configure app as menu bar utility with settings window (`MenuBarExtra` + `Settings` scene).
- [x] Add app icon placeholder (`Assets.xcassets/AppIcon.appiconset`).
- [ ] Add signing and notarization notes. (Phase 4)
- [ ] Add test target in Xcode project. (SPM `swift test` covers Phase 0 Core tests; Xcode UI test target added when needed.)

## 2. Build Core — DONE

- [x] Create `ModuleID`, `ModuleState`, `SystemPermission`, and `DropThingsModule`.
- [x] Create `ModuleRegistry`.
- [x] Create `SettingsStore` with typed keys.
- [x] Create `PermissionCenter`.
- [x] Create `DiagnosticsStore`.
- [x] Create logging helpers (`ModuleLogger`).

## 3. Build Design System — DONE

- [x] Add `DesignTokens.swift` from `docs/design-tokens.json`.
- [x] Add shared spacing, radius, color, and typography helpers.
- [x] Add `ModuleRow`.
- [x] Add `SettingsSection`.
- [x] Add `PermissionRow`.
- [x] Add `InlineAlert`.
- [x] Add `ModuleStatusPill`.
- [x] Add empty, error, and permission-denied states (inline in `ModuleDetailView`).

## 4. Build Settings Shell

- [x] Add sidebar with modules.
- [x] Add module detail pane.
- [x] Add global diagnostics page.
- [x] Add about/version page.
- [x] Add manual `NSWindow` (avoids the `Settings` scene race with `.accessory` activation policy).

## 5. Implement File Shelf

- [x] Create shelf module settings model (`FileShelfSettings` + typed `SettingsStore` keys).
- [x] Create floating `NSPanel` (`ShelfPanel` + `ShelfContentView` in `DropThingsPlatform/Adapters`).
- [x] Implement drop target via `NSDraggingDestination` (AppKit, not SwiftUI `.onDrop`).
- [x] Parse pasteboard items (`PasteboardItemReader` — file URLs, plain text; legacy `.filenames` fallback).
- [x] Render shelf items (`ShelfView` + `ShelfItemRow` with empty state and per-item remove).
- [x] Add remove and clear actions; "Clear shelf when disabled" toggle.
- [x] Implement drag-out behavior (SwiftUI `.onDrag` returns `NSItemProvider` per kind).
- [x] Add Reveal in Finder and Copy path actions (context menu on each row).
- [x] Add hotkey ⌥⌘S via Carbon `RegisterEventHotKey` (`GlobalHotkey` adapter in Platform).
- [x] Add menu-bar "Show File Shelf" entry (MenuBarExtra).
- [x] Add manual verification notes for File Shelf (`docs/file-shelf-manual-checks.md`).
- [x] Add pin action + persistence to `~/Library/Application Support/app.dropthings/file-shelf-pinned.json`.
- [x] Cap respects pinned items: unpinned entries are trimmed first when the shelf is full.
- [x] Hotkey is user-editable via `ShortcutRecorder`; default ⌥⌘S.

## 6. Implement Scroll Control

- [x] Add tests for scroll transform decisions (`ScrollEventTransformerTests`, 16 tests).
- [x] Add settings round-trip tests (`ScrollSettingsTests`, 5 tests).
- [x] Add manual verification notes for mouse, trackpad, and Magic Mouse (`docs/scroll-control-manual-checks.md`).

## 8. Phase 4 — Polish & Reliability

- [x] First-run onboarding window (`OnboardingWindowController` + `OnboardingView`).
- [x] Settings import / export via `defaults export` / `defaults import` (`SettingsImporter`).
- [x] Request-Access button on every permission row (Accessibility + Screen Recording).
- [x] Manual verification notes consolidated in `docs/manual-checks.md`.
- [x] Release, signing, notarization instructions in `docs/RELEASE.md`.
- [ ] Crash reporting (skipped per privacy principles).
- [ ] Auto-update (Sparkle integration deferred; manual update path documented).

## 9. Open Items (post-MVP)

- Hover-to-reveal for Menu Bar Cleaner.
- Auto-hide delay for Menu Bar Cleaner.
- Compact mode for notch / small screens.
- Compatibility matrix by macOS version for Menu Bar Cleaner.
- Hotkey customization (currently hardcoded to ⌥⌘S for File Shelf).
- Auto-update via Sparkle.
- Crash reporting (opt-in, privacy-respecting).


