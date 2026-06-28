# Architecture

## Stack

- Language: Swift.
- UI: SwiftUI for settings and module screens.
- macOS integration: AppKit, CoreGraphics, Accessibility, IOKit, Launch Services.
- Persistence: typed settings over `UserDefaults`, with a future path to SQLite if needed.
- Distribution: start with direct signed/notarized builds; revisit App Store once permissions are proven.
- Build: SwiftPM library targets for the modular code, one Xcode app target that owns the bundle. See `docs/decisions.md`.

## High-Level Structure

```text
DropThings/
  App/                          # Xcode app target only
    DropThingsApp.swift
    SettingsRootView.swift
    Info.plist
    DropThings.entitlements
    Assets.xcassets/
  App.xcodeproj/
  Package.swift                 # 4 SPM library targets
  Sources/
    DropThingsCore/             # Module registry, settings, permissions, diagnostics, logging
    DropThingsDesignSystem/     # Tokens + shared components
      Tokens/
      Components/
    DropThingsPlatform/         # Adapters for AppKit, CGEvent, accessibility, etc.
    DropThingsModules/          # Feature modules (one folder per module)
      FileShelf/
      ScrollControl/
      MenuBarCleaner/
  Tests/
    DropThingsCoreTests/
```

## Module Contract

Every module should expose:

```swift
protocol DropThingsModule {
    var id: ModuleID { get }
    var name: String { get }
    var summary: String { get }
    var requiredPermissions: [SystemPermission] { get }
    var state: ModuleState { get }

    func start() async throws
    func stop() async
    func makeSettingsView() -> AnyView
}
```

Keep the real protocol minimal when implemented. Add methods only when at least two modules need them.

## Core Responsibilities

- Register modules.
- Store enabled/disabled state.
- Start enabled modules at launch.
- Surface module health and permission status.
- Provide shared services: logging, settings, permissions, file bookmarks.
- Keep modules isolated.

## Module Boundaries

- `FileShelf` must not know about scroll or menu bar internals.
- `ScrollControl` must not render shared settings chrome itself.
- `MenuBarCleaner` must not own app-wide menu bar status items except through a core menu bar service.
- Shared UI components belong in `DesignSystem`, not inside a module.

## Platform Adapters

Fragile APIs must live behind small adapters:

- `EventTapClient`: create, enable, disable, and recover event taps.
- `InputDeviceClassifier`: classify input devices.
- `DraggingShelfWindow`: AppKit drag destination/source behavior.
- `StatusItemController`: own app menu bar item.
- `MenuBarInspectionClient`: menu bar item discovery and manipulation, if feasible.
- `AccessibilityPermissionClient`: query and request permissions.

## Failure Model

Every module needs these states:

- `off`: user disabled it.
- `starting`: initialization in progress.
- `running`: active.
- `needsPermission`: blocked by macOS permission.
- `unavailable`: unsupported macOS version or hardware.
- `degraded`: partially working.
- `failed`: error with recovery action.

