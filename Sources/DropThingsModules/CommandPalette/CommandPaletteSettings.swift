import Carbon.HIToolbox
import Foundation
import DropThingsCore
import DropThingsPlatform

public struct CommandPaletteSettings: Sendable, Equatable, Codable {
    public static let currentVersion = 3

    public var version: Int
    public var hotkeyEnabled: Bool
    public var hotkey: GlobalHotkey.Definition?
    public var applicationsEnabled: Bool
    public var commandsEnabled: Bool
    public var calculatorEnabled: Bool
    public var filesEnabled: Bool
    public var fileContentSearchEnabled: Bool
    public var includeHiddenFiles: Bool
    public var applicationLocations: [String]
    public var applicationExcludedPaths: [String]
    public var applicationVisibility: ApplicationVisibilityMode
    public var selectedApplicationIDs: [String]
    public var pinnedApplicationIDs: [String]
    public var excludedPaths: [String]
    public var webSearchEnabled: Bool
    public var webSearchEngine: WebSearchEngine
    public var webBrowserBundleIdentifier: String?
    public var maximumResultsPerProvider: Int

    public init(
        version: Int = currentVersion,
        hotkeyEnabled: Bool = true,
        hotkey: GlobalHotkey.Definition? = GlobalHotkey.defaultCommandPaletteHotkey,
        applicationsEnabled: Bool = true,
        commandsEnabled: Bool = true,
        calculatorEnabled: Bool = true,
        filesEnabled: Bool = true,
        fileContentSearchEnabled: Bool = false,
        includeHiddenFiles: Bool = false,
        applicationLocations: [String] = [],
        applicationExcludedPaths: [String] = [],
        applicationVisibility: ApplicationVisibilityMode = .all,
        selectedApplicationIDs: [String] = [],
        pinnedApplicationIDs: [String] = [],
        excludedPaths: [String] = [],
        webSearchEnabled: Bool = false,
        webSearchEngine: WebSearchEngine = .google,
        webBrowserBundleIdentifier: String? = nil,
        maximumResultsPerProvider: Int = 30
    ) {
        self.version = version
        self.hotkeyEnabled = hotkeyEnabled
        self.hotkey = hotkey
        self.applicationsEnabled = applicationsEnabled
        self.commandsEnabled = commandsEnabled
        self.calculatorEnabled = calculatorEnabled
        self.filesEnabled = filesEnabled
        self.fileContentSearchEnabled = fileContentSearchEnabled
        self.includeHiddenFiles = includeHiddenFiles
        self.applicationLocations = applicationLocations
        self.applicationExcludedPaths = applicationExcludedPaths
        self.applicationVisibility = applicationVisibility
        self.selectedApplicationIDs = selectedApplicationIDs
        self.pinnedApplicationIDs = pinnedApplicationIDs
        self.excludedPaths = excludedPaths
        self.webSearchEnabled = webSearchEnabled
        self.webSearchEngine = webSearchEngine
        self.webBrowserBundleIdentifier = webBrowserBundleIdentifier
        self.maximumResultsPerProvider = max(5, min(maximumResultsPerProvider, 100))
    }

    enum CodingKeys: String, CodingKey {
        case version, hotkeyEnabled, hotkey, applicationsEnabled, commandsEnabled, calculatorEnabled
        case filesEnabled, fileContentSearchEnabled, includeHiddenFiles, applicationLocations, applicationExcludedPaths
        case applicationVisibility, selectedApplicationIDs, pinnedApplicationIDs, excludedPaths
        case webSearchEnabled, webSearchEngine, webBrowserBundleIdentifier
        case maximumResultsPerProvider
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedHotkey: GlobalHotkey.Definition?
        if c.contains(.hotkey) {
            decodedHotkey = try c.decodeIfPresent(GlobalHotkey.Definition.self, forKey: .hotkey)
        } else {
            decodedHotkey = GlobalHotkey.defaultCommandPaletteHotkey
        }
        self.init(
            version: Self.currentVersion,
            hotkeyEnabled: try c.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true,
            hotkey: decodedHotkey,
            applicationsEnabled: try c.decodeIfPresent(Bool.self, forKey: .applicationsEnabled) ?? true,
            commandsEnabled: try c.decodeIfPresent(Bool.self, forKey: .commandsEnabled) ?? true,
            calculatorEnabled: try c.decodeIfPresent(Bool.self, forKey: .calculatorEnabled) ?? true,
            filesEnabled: try c.decodeIfPresent(Bool.self, forKey: .filesEnabled) ?? true,
            fileContentSearchEnabled: try c.decodeIfPresent(Bool.self, forKey: .fileContentSearchEnabled) ?? false,
            includeHiddenFiles: try c.decodeIfPresent(Bool.self, forKey: .includeHiddenFiles) ?? false,
            applicationLocations: try c.decodeIfPresent([String].self, forKey: .applicationLocations) ?? [],
            applicationExcludedPaths: try c.decodeIfPresent([String].self, forKey: .applicationExcludedPaths) ?? [],
            applicationVisibility: try c.decodeIfPresent(ApplicationVisibilityMode.self, forKey: .applicationVisibility) ?? .all,
            selectedApplicationIDs: try c.decodeIfPresent([String].self, forKey: .selectedApplicationIDs) ?? [],
            pinnedApplicationIDs: try c.decodeIfPresent([String].self, forKey: .pinnedApplicationIDs) ?? [],
            excludedPaths: try c.decodeIfPresent([String].self, forKey: .excludedPaths) ?? [],
            webSearchEnabled: try c.decodeIfPresent(Bool.self, forKey: .webSearchEnabled) ?? false,
            webSearchEngine: try c.decodeIfPresent(WebSearchEngine.self, forKey: .webSearchEngine) ?? .google,
            webBrowserBundleIdentifier: try c.decodeIfPresent(String.self, forKey: .webBrowserBundleIdentifier),
            maximumResultsPerProvider: try c.decodeIfPresent(Int.self, forKey: .maximumResultsPerProvider) ?? 30
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(hotkeyEnabled, forKey: .hotkeyEnabled)
        if let hotkey { try c.encode(hotkey, forKey: .hotkey) } else { try c.encodeNil(forKey: .hotkey) }
        try c.encode(applicationsEnabled, forKey: .applicationsEnabled)
        try c.encode(commandsEnabled, forKey: .commandsEnabled)
        try c.encode(calculatorEnabled, forKey: .calculatorEnabled)
        try c.encode(filesEnabled, forKey: .filesEnabled)
        try c.encode(fileContentSearchEnabled, forKey: .fileContentSearchEnabled)
        try c.encode(includeHiddenFiles, forKey: .includeHiddenFiles)
        try c.encode(applicationLocations, forKey: .applicationLocations)
        try c.encode(applicationExcludedPaths, forKey: .applicationExcludedPaths)
        try c.encode(applicationVisibility, forKey: .applicationVisibility)
        try c.encode(selectedApplicationIDs, forKey: .selectedApplicationIDs)
        try c.encode(pinnedApplicationIDs, forKey: .pinnedApplicationIDs)
        try c.encode(excludedPaths, forKey: .excludedPaths)
        try c.encode(webSearchEnabled, forKey: .webSearchEnabled)
        try c.encode(webSearchEngine, forKey: .webSearchEngine)
        try c.encodeIfPresent(webBrowserBundleIdentifier, forKey: .webBrowserBundleIdentifier)
        try c.encode(maximumResultsPerProvider, forKey: .maximumResultsPerProvider)
    }

    public func sanitized() -> CommandPaletteSettings {
        CommandPaletteSettings(
            hotkeyEnabled: hotkeyEnabled,
            hotkey: hotkey,
            applicationsEnabled: applicationsEnabled,
            commandsEnabled: commandsEnabled,
            calculatorEnabled: calculatorEnabled,
            filesEnabled: filesEnabled,
            fileContentSearchEnabled: fileContentSearchEnabled,
            includeHiddenFiles: includeHiddenFiles,
            applicationLocations: Self.cleanedPaths(applicationLocations),
            applicationExcludedPaths: Self.cleanedPaths(applicationExcludedPaths),
            applicationVisibility: applicationVisibility,
            selectedApplicationIDs: Self.cleanedIDs(selectedApplicationIDs),
            pinnedApplicationIDs: Self.cleanedIDs(pinnedApplicationIDs),
            excludedPaths: Self.cleanedPaths(excludedPaths),
            webSearchEnabled: webSearchEnabled,
            webSearchEngine: webSearchEngine,
            webBrowserBundleIdentifier: webBrowserBundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            maximumResultsPerProvider: maximumResultsPerProvider
        )
    }

    private static func cleanedPaths(_ paths: [String]) -> [String] {
        Array(Set(paths.map { NSString(string: $0).expandingTildeInPath }.filter { !$0.isEmpty })).sorted()
    }

    private static func cleanedIDs(_ ids: [String]) -> [String] {
        Array(Set(ids.filter { !$0.isEmpty })).sorted()
    }
}

public enum ApplicationVisibilityMode: String, Codable, CaseIterable, Sendable {
    case all
    case selected

    public var displayName: String { self == .all ? "All applications" : "Only selected applications" }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

public enum CommandPaletteSettingsKey {
    public static let settings = SettingsKey("modules.command-palette.settings")
}

public extension SettingsStore {
    func loadCommandPaletteSettings() -> CommandPaletteSettings {
        guard let data = data(CommandPaletteSettingsKey.settings) else {
            return CommandPaletteSettings()
        }
        guard let decoded = try? JSONDecoder().decode(CommandPaletteSettings.self, from: data) else {
            remove(CommandPaletteSettingsKey.settings)
            return CommandPaletteSettings()
        }
        let migrated = decoded.sanitized()
        if migrated != decoded { saveCommandPaletteSettings(migrated) }
        return migrated
    }

    func saveCommandPaletteSettings(_ settings: CommandPaletteSettings) {
        guard let data = try? JSONEncoder().encode(settings.sanitized()) else { return }
        setData(data, CommandPaletteSettingsKey.settings)
    }
}

public extension GlobalHotkey {
    static var defaultCommandPaletteHotkey: Definition? {
        Definition(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey), id: 3)
    }
}
