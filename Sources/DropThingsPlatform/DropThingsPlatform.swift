import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Namespace for fragile macOS API adapters. Real adapters (event tap, NSPanel
/// drag/drop, status item, accessibility, IOKit device classification, launch
/// services) are added one per concrete need from `DropThingsModules` —
/// never speculatively. See `docs/architecture.md` and `AGENTS.md`.
///
/// Imports are listed so this file compiles in the same batch as the
/// AppKit/SwiftUI-touching adapters next to it. Without that, SwiftPM can
/// emit the module before `Adapters/ShelfPanel.swift` is compiled and the
/// dependent target then fails to resolve `ShelfPanel`.
public enum DropThingsPlatform {}
