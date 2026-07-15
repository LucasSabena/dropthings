# Architecture audit: DesignSystem → Platform dependency

Date: 2026-07-14  
Repository: `LucasSabena/dropthings`

## Finding

`Package.swift` documents the intended graph as:

```text
Core         -> none
DesignSystem -> Core
Platform     -> Core
Modules      -> Core, DesignSystem, Platform
```

The actual target declaration makes `DropThingsDesignSystem` depend on both Core and
Platform. The concrete import is
`Sources/DropThingsDesignSystem/Components/ShortcutRecorder.swift`, which imports
`DropThingsPlatform` to use `GlobalHotkey.Definition`.

This is not necessarily a current runtime bug, but it weakens the stated layering:
a tokens/components target knows a platform adapter type. The new modules add more
hotkeys and shared controls, so the ambiguity should be removed first.

## Options

### A. Accept and document DesignSystem → Platform

Fastest, but DesignSystem can gradually absorb event taps, Accessibility and other
fragile platform concerns. Reject unless the target is deliberately renamed and
redefined as a broader macOS UI layer.

### B. Move ShortcutRecorder into Platform

Removes the import but places a reusable visual component in the adapter layer. This
is an acceptable emergency cleanup, not the preferred boundary.

### C. Move the semantic shortcut value to Core; keep registration in Platform

**Recommended.**

Core should own a platform-neutral Codable/Hashable/Sendable shortcut value:

```swift
public struct KeyboardShortcutDefinition: Codable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: KeyboardShortcutModifiers
    public var id: UInt32
}

public struct KeyboardShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    public static let command: Self
    public static let option: Self
    public static let control: Self
    public static let shift: Self
}
```

- Core owns persisted semantic identity and validation.
- DesignSystem's recorder converts `NSEvent.ModifierFlags` to semantic modifiers
  and renders the human label.
- Platform's `GlobalHotkey` converts the Core value to Carbon/event-tap flags and
  owns registration/errors.
- Modules store the Core value and inject the Platform registrar.

Do not store localized display strings as identity.

## Migration

1. Capture fixture examples of the current encoded `GlobalHotkey.Definition`.
2. Add Core types and conversion/validation tests.
3. Add Platform conversion from Core to the current registration representation.
4. Update ShortcutRecorder to bind Core and remove `import DropThingsPlatform`.
5. Migrate module settings without resetting user shortcuts; preserve field/raw
   compatibility or add custom/versioned decoding.
6. Remove Platform from DesignSystem dependencies in `Package.swift`.
7. Update AGENTS/architecture docs to name the semantic shortcut boundary.

## Verification

- No `import DropThingsPlatform` under `Sources/DropThingsDesignSystem`.
- Build graph shows DesignSystem → Core only.
- Existing shortcuts survive relaunch/migration.
- Recorder clear/cancel/capture, conflict errors and every module hotkey are tested.
- Full tests plus Debug/Release builds pass.

## Stop condition

If Core must import AppKit, Carbon or event-tap APIs, the split is wrong. Core remains
semantic; all registration/platform conversion remains in Platform.
