// swift-tools-version: 5.10
import PackageDescription

// DropThings is structured as four SwiftPM library targets so the system-level code
// can be developed and tested without dragging in AppKit/SwiftUI where it is not
// needed. The macOS app target lives in App.xcodeproj and links these as local
// library products.
//
// Dependency rules (enforced by Package.swift, not just docs):
//   Core            -> (none)
//   DesignSystem    -> Core (only for shared state names)
//   Platform        -> Core
//   Modules         -> Core, DesignSystem, Platform
//   Modules MUST NOT depend on each other.

let package = Package(
    name: "DropThings",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DropThingsCore", targets: ["DropThingsCore"]),
        .library(name: "DropThingsDesignSystem", targets: ["DropThingsDesignSystem"]),
        .library(name: "DropThingsPlatform", targets: ["DropThingsPlatform"]),
        .library(name: "DropThingsModules", targets: ["DropThingsModules"])
    ],
    targets: [
        .target(
            name: "DropThingsCore",
            path: "Sources/DropThingsCore"
        ),
        .target(
            name: "DropThingsDesignSystem",
            dependencies: ["DropThingsCore", "DropThingsPlatform"],
            path: "Sources/DropThingsDesignSystem"
        ),
        .target(
            name: "DropThingsPlatform",
            dependencies: ["DropThingsCore"],
            path: "Sources/DropThingsPlatform"
        ),
        .target(
            name: "DropThingsModules",
            dependencies: [
                "DropThingsCore",
                "DropThingsDesignSystem",
                "DropThingsPlatform"
            ],
            path: "Sources/DropThingsModules"
        ),
        .testTarget(
            name: "DropThingsCoreTests",
            dependencies: ["DropThingsCore"],
            path: "Tests/DropThingsCoreTests"
        ),
        .testTarget(
            name: "DropThingsModulesTests",
            dependencies: ["DropThingsCore", "DropThingsModules"],
            path: "Tests/DropThingsModulesTests"
        )
    ]
)
