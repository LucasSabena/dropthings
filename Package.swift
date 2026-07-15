// swift-tools-version: 5.10
import PackageDescription

// DropThings is structured as small SwiftPM library targets so the system-level code
// can be developed and tested without dragging in AppKit/SwiftUI where it is not
// needed. The macOS app target lives in App.xcodeproj and links these as local
// library products.
//
// Dependency rules (enforced by Package.swift, not just docs):
//   Core             -> (none)
//   Foundation kits  -> (none)
//   DesignSystem     -> Core (plus the currently documented Platform exception)
//   Platform         -> Core, justified Foundation kits
//   Modules          -> Core, DesignSystem, Platform, justified Foundation kits
//   Modules MUST NOT depend on each other.

let package = Package(
    name: "DropThings",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DropThingsCore", targets: ["DropThingsCore"]),
        .library(name: "DropThingsAudioControlKit", targets: ["DropThingsAudioControlKit"]),
        .library(name: "DropThingsTranscriptionKit", targets: ["DropThingsTranscriptionKit"]),
        .library(name: "DropThingsWhisperEngine", targets: ["DropThingsWhisperEngine"]),
        .library(name: "DropThingsMediaConverterKit", targets: ["DropThingsMediaConverterKit"]),
        .library(name: "DropThingsDesignSystem", targets: ["DropThingsDesignSystem"]),
        .library(name: "DropThingsPlatform", targets: ["DropThingsPlatform"]),
        .library(name: "DropThingsModules", targets: ["DropThingsModules"])
    ],
    targets: [
        .target(
            name: "DropThingsAudioControlKit",
            path: "Sources/DropThingsAudioControlKit"
        ),
        .target(
            name: "DropThingsTranscriptionKit",
            path: "Sources/DropThingsTranscriptionKit"
        ),
        .binaryTarget(
            name: "WhisperFramework",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.9.1/whisper-v1.9.1-xcframework.zip",
            checksum: "8c3ecbe73f48b0cb9318fc3058264f951ab336fd530e82c4ccdd2298d1311a4c"
        ),
        .target(
            name: "DropThingsWhisperEngine",
            dependencies: ["DropThingsTranscriptionKit", "WhisperFramework"],
            path: "Sources/DropThingsWhisperEngine"
        ),
        .target(
            name: "DropThingsMediaConverterKit",
            path: "Sources/DropThingsMediaConverterKit"
        ),
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
            dependencies: ["DropThingsCore", "DropThingsAudioControlKit", "DropThingsTranscriptionKit", "DropThingsMediaConverterKit"],
            path: "Sources/DropThingsPlatform",
            exclude: [
                "Adapters/DropThingsStatusItem.swift",
                "Adapters/HoverTrackingView.swift",
                "Adapters/WindowSnapper.swift"
            ]
        ),
        .target(
            name: "DropThingsModules",
            dependencies: [
                "DropThingsCore",
                "DropThingsAudioControlKit",
                "DropThingsTranscriptionKit",
                "DropThingsMediaConverterKit",
                "DropThingsDesignSystem",
                "DropThingsPlatform"
            ],
            path: "Sources/DropThingsModules",
            exclude: [
                "MenuBarCleaner",
                "ScreenshotRegion",
                "Snippets",
                "TextTools",
                "WindowSnap"
            ],
            resources: [
                .copy("MarkdownViewer/Resources")
            ]
        ),
        .testTarget(
            name: "DropThingsCoreTests",
            dependencies: ["DropThingsCore"],
            path: "Tests/DropThingsCoreTests"
        ),
        .testTarget(
            name: "DropThingsAudioControlKitTests",
            dependencies: ["DropThingsAudioControlKit"],
            path: "Tests/DropThingsAudioControlKitTests"
        ),
        .testTarget(
            name: "DropThingsTranscriptionKitTests",
            dependencies: ["DropThingsTranscriptionKit"],
            path: "Tests/DropThingsTranscriptionKitTests"
        ),
        .testTarget(
            name: "DropThingsWhisperEngineTests",
            dependencies: ["DropThingsWhisperEngine"],
            path: "Tests/DropThingsWhisperEngineTests"
        ),
        .testTarget(
            name: "DropThingsMediaConverterKitTests",
            dependencies: ["DropThingsMediaConverterKit"],
            path: "Tests/DropThingsMediaConverterKitTests"
        ),
        .testTarget(
            name: "DropThingsModulesTests",
            dependencies: ["DropThingsCore", "DropThingsModules", "DropThingsPlatform"],
            path: "Tests/DropThingsModulesTests",
            exclude: [
                "MenuBarCleaner",
                "ScreenshotRegion",
                "Snippets",
                "TextTools",
                "WindowSnap"
            ]
        )
    ]
)
