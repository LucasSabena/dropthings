import Foundation
import DropThingsCore
import DropThingsPlatform

/// Module-private provider seam. Providers build immutable result values off
/// the main actor; only their action closures hop back to AppKit services.
protocol PaletteLocalSearchProviding: Sendable {
    var id: PaletteProviderID { get }
    func results(in context: PaletteLocalProviderContext) -> [PaletteResult]
}

struct PaletteLocalProviderContext: Sendable {
    let query: String
    let settings: CommandPaletteSettings
    let applications: [ApplicationRecord]
    let catalogApplications: [ApplicationRecord]
    let commands: [CommandDescriptor]
    let calculator: CalculatorEngine
    let workspace: PaletteWorkspace
    let togglePinnedApplication: @MainActor @Sendable (String) -> Void
}

struct ApplicationPaletteProvider: PaletteLocalSearchProviding {
    let id = PaletteProviderID.applications

    func results(in context: PaletteLocalProviderContext) -> [PaletteResult] {
        guard context.settings.applicationsEnabled else { return [] }
        let pinnedIDs = Set(context.settings.pinnedApplicationIDs)
        return context.applications.map { app in
            let isPinned = pinnedIDs.contains(app.id)
            return PaletteResult(
                id: app.id,
                kind: .application,
                title: app.name,
                subtitle: app.url.deletingLastPathComponent().path,
                aliases: app.aliases + [app.bundleIdentifier].compactMap { $0 },
                icon: .application(app.url),
                providerPriority: isPinned ? 620 : 260,
                actions: [
                    PaletteAction(id: "open", title: "Open", symbolName: "arrow.up.forward.app", shortcutHint: "↩", role: .primary) { [workspace = context.workspace] in
                        try await workspace.launchApplication(at: app.url)
                    },
                    PaletteAction(id: "reveal", title: "Reveal in Finder", symbolName: "folder", shortcutHint: "⌘↩") { [workspace = context.workspace] in
                        try workspace.reveal(app.url)
                    },
                    PaletteAction(id: "copy-path", title: "Copy Path", symbolName: "doc.on.doc", role: .copy) { [workspace = context.workspace] in
                        workspace.copyPath(app.url)
                    },
                    PaletteAction(
                        id: "toggle-pin",
                        title: isPinned ? "Unpin Application" : "Pin Application",
                        symbolName: isPinned ? "pin.slash" : "pin"
                    ) { [togglePinnedApplication = context.togglePinnedApplication] in
                        togglePinnedApplication(app.id)
                    }
                ]
            )
        }
    }
}

struct CommandResultProvider: PaletteLocalSearchProviding {
    let id = PaletteProviderID.commands

    func results(in context: PaletteLocalProviderContext) -> [PaletteResult] {
        guard context.settings.commandsEnabled else { return [] }
        var results = context.commands.map { command in
            PaletteResult(
                id: "command:\(command.id)",
                kind: .command,
                title: command.title,
                subtitle: command.subtitle,
                icon: .system(command.iconName ?? "command"),
                providerPriority: 230,
                actions: [PaletteAction(id: "run", title: "Run", symbolName: "return", shortcutHint: "↩", role: .primary) {
                    command.action()
                }]
            )
        }
        if let settingsURL = URL(string: "x-apple.systempreferences:") {
            results.append(PaletteResult(
                id: "system:open-settings",
                kind: .systemAction,
                title: "Open System Settings",
                subtitle: "macOS",
                aliases: ["preferences", "configuration"],
                icon: .system("gearshape"),
                providerPriority: 190,
                actions: [PaletteAction(id: "open", title: "Open", symbolName: "gearshape", shortcutHint: "↩", role: .primary) { [workspace = context.workspace] in
                    try workspace.openExternal(settingsURL)
                }]
            ))
        }
        return results
    }
}

struct CalculatorResultProvider: PaletteLocalSearchProviding {
    let id = PaletteProviderID.calculator

    func results(in context: PaletteLocalProviderContext) -> [PaletteResult] {
        guard context.settings.calculatorEnabled,
              let calculation = context.calculator.resultIfCalculation(context.query) else { return [] }
        return [PaletteResult(
            id: "calculation:\(calculation.value.bitPattern)",
            kind: .calculation,
            title: calculation.formatted,
            subtitle: calculation.expression,
            icon: .system("equal.circle"),
            providerPriority: 420,
            actions: [PaletteAction(id: "copy", title: "Copy Result", symbolName: "doc.on.doc", shortcutHint: "↩", role: .primary) { [workspace = context.workspace] in
                workspace.copyText(calculation.formatted)
            }]
        )]
    }
}

struct WebResultProvider: PaletteLocalSearchProviding {
    let id = PaletteProviderID.web

    func results(in context: PaletteLocalProviderContext) -> [PaletteResult] {
        let query = context.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard context.settings.webSearchEnabled,
              !query.isEmpty,
              let url = context.settings.webSearchEngine.searchURL(for: query) else { return [] }
        let engine = context.settings.webSearchEngine
        let browserName: String
        if let bundleID = context.settings.webBrowserBundleIdentifier {
            browserName = context.catalogApplications.first(where: { $0.bundleIdentifier == bundleID })?.name ?? bundleID
        } else {
            browserName = "System default browser"
        }
        return [PaletteResult(
            id: "web:\(engine.rawValue):\(query)",
            kind: .webSearch,
            title: "Search \(engine.displayName) for “\(query)”",
            subtitle: browserName,
            aliases: [query, "internet", "web"],
            icon: .system("globe"),
            providerPriority: 130,
            actions: [PaletteAction(id: "search", title: "Search the Web", symbolName: "globe", shortcutHint: "↩", role: .primary) { [workspace = context.workspace] in
                try await workspace.openWebURL(url, browserBundleIdentifier: context.settings.webBrowserBundleIdentifier)
            }]
        )]
    }
}

struct SystemSearchResultProvider: PaletteLocalSearchProviding {
    let id = PaletteProviderID.web

    func results(in context: PaletteLocalProviderContext) -> [PaletteResult] {
        let query = context.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return [PaletteResult(
            id: "system-search:\(query)",
            kind: .systemSearch,
            title: "Search this Mac for “\(query)”",
            subtitle: "Finder · Spotlight",
            aliases: [query, "system", "spotlight", "finder"],
            icon: .system("magnifyingglass.circle"),
            providerPriority: 120,
            actions: [PaletteAction(id: "search-system", title: "Search this Mac", symbolName: "magnifyingglass", shortcutHint: "↩", role: .primary) { [workspace = context.workspace] in
                try workspace.searchSystem(for: query)
            }]
        )]
    }
}

enum PaletteFileResultFactory {
    static func results(for records: [SpotlightFileRecord], workspace: PaletteWorkspace) -> [PaletteResult] {
        records.map { record in
            let kind: PaletteResultKind = record.isDirectory ? .folder : .file
            return PaletteResult(
                id: record.id,
                kind: kind,
                title: record.name,
                subtitle: record.parentPath,
                icon: .file(record.url, isDirectory: record.isDirectory),
                providerPriority: 160,
                providerRelevance: record.relevance,
                actions: [
                    PaletteAction(id: "open", title: record.isDirectory ? "Open Folder" : "Open", symbolName: "arrow.up.forward.app", shortcutHint: "↩", role: .primary) {
                        try workspace.open(record.url)
                    },
                    PaletteAction(id: "reveal", title: "Reveal in Finder", symbolName: "folder", shortcutHint: "⌘↩") {
                        try workspace.reveal(record.url)
                    },
                    PaletteAction(id: "quick-look", title: "Quick Look", symbolName: "eye", role: .preview) {
                        try workspace.quickLook(record.url)
                    },
                    PaletteAction(id: "copy-path", title: "Copy Path", symbolName: "doc.on.doc", role: .copy) {
                        workspace.copyPath(record.url)
                    },
                    PaletteAction(id: "containing-folder", title: "Open Containing Folder", symbolName: "folder.badge.plus") {
                        try workspace.openContainingFolder(of: record.url)
                    }
                ]
            )
        }
    }
}
