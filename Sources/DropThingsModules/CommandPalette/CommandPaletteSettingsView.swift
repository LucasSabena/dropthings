import SwiftUI
import DropThingsDesignSystem
import DropThingsPlatform

struct CommandPaletteSettingsView: View {
    @ObservedObject var module: CommandPaletteModule
    @State private var exclusionsText = ""
    @State private var appLocationsText = ""
    @State private var appExclusionsText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.lg) {
            SettingsSection(title: "Command Palette", caption: "A fast launcher for applications, DropThings actions, Spotlight files, calculations, and optional web search.") {
                VStack(alignment: .leading, spacing: DTSpace.md) {
                    Button { module.show() } label: { Label("Open Command Palette", systemImage: "command") }
                    Toggle("Enable global shortcut", isOn: binding(\.hotkeyEnabled, module.setHotkeyEnabled))
                    ShortcutRecorder(
                        title: "Open Command Palette",
                        definition: Binding(get: { module.settings.hotkey }, set: module.setHotkey)
                    )
                }
            }

            SettingsSection(title: "Applications", caption: "Pinned apps appear first when the palette opens. Choose whether the catalog shows every app or only your selection.") {
                VStack(alignment: .leading, spacing: DTSpace.sm) {
                    Picker("Applications shown", selection: Binding(
                        get: { module.settings.applicationVisibility },
                        set: module.setApplicationVisibility
                    )) {
                        ForEach(ApplicationVisibilityMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    ScrollView {
                        LazyVStack(spacing: DTSpace.xs) {
                            ForEach(module.coordinator.availableApplications, id: \.id) { application in
                                applicationRow(application)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                    .overlay(RoundedRectangle(cornerRadius: DTRadius.md).strokeBorder(DTColor.border))
                }
            }

            SettingsSection(title: "Web search", caption: "Disabled by default. The query leaves this Mac only when you execute the web-search result.") {
                VStack(alignment: .leading, spacing: DTSpace.sm) {
                    Toggle("Show web search results", isOn: binding(\.webSearchEnabled, module.setWebSearchEnabled))
                    Picker("Search engine", selection: Binding(
                        get: { module.settings.webSearchEngine },
                        set: module.setWebSearchEngine
                    )) {
                        ForEach(WebSearchEngine.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    .disabled(!module.settings.webSearchEnabled)
                    Picker("Browser", selection: Binding(
                        get: { module.settings.webBrowserBundleIdentifier ?? "" },
                        set: { module.setWebBrowserBundleIdentifier($0.isEmpty ? nil : $0) }
                    )) {
                        Text("System default browser").tag("")
                        ForEach(module.coordinator.availableBrowsers, id: \.id) { browser in
                            if let bundleIdentifier = browser.bundleIdentifier {
                                Text(browser.name).tag(bundleIdentifier)
                            }
                        }
                    }
                    .disabled(!module.settings.webSearchEnabled)
                    Text("If the selected browser is running, macOS sends the search to that process. Its own preferences decide whether to use a tab or window; otherwise it launches.")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                }
            }

            SettingsSection(title: "Providers", caption: "Fast providers remain available when Spotlight is slow or unavailable.") {
                VStack(alignment: .leading, spacing: DTSpace.sm) {
                    providerToggle("Applications", .applications, module.settings.applicationsEnabled)
                    providerToggle("DropThings commands", .commands, module.settings.commandsEnabled)
                    providerToggle("Calculator", .calculator, module.settings.calculatorEnabled)
                    providerToggle("Files and folders (Spotlight)", .files, module.settings.filesEnabled)
                    Toggle("Search file contents", isOn: binding(\.fileContentSearchEnabled, module.setFileContentSearchEnabled))
                        .disabled(!module.settings.filesEnabled)
                    Toggle("Include hidden files", isOn: binding(\.includeHiddenFiles, module.setIncludeHiddenFiles))
                        .disabled(!module.settings.filesEnabled)
                    Stepper(
                        "Maximum results per provider: \(module.settings.maximumResultsPerProvider)",
                        value: Binding(get: { module.settings.maximumResultsPerProvider }, set: module.setMaximumResultsPerProvider),
                        in: 5...100,
                        step: 5
                    )
                }
            }

            SettingsSection(title: "Locations", caption: "One path per line. Spotlight cannot return excluded, unindexed, remote-only, or inaccessible items.") {
                VStack(alignment: .leading, spacing: DTSpace.sm) {
                    Text("Additional application folders").font(DTTypography.body)
                    TextEditor(text: $appLocationsText)
                        .font(DTTypography.monospacedBody)
                        .frame(minHeight: 56)
                        .overlay(RoundedRectangle(cornerRadius: DTRadius.sm).strokeBorder(DTColor.border))
                        .onChange(of: appLocationsText) { _, value in module.setApplicationLocations(lines(value)) }
                    Text("Excluded file paths").font(DTTypography.body)
                    TextEditor(text: $exclusionsText)
                        .font(DTTypography.monospacedBody)
                        .frame(minHeight: 56)
                        .overlay(RoundedRectangle(cornerRadius: DTRadius.sm).strokeBorder(DTColor.border))
                        .onChange(of: exclusionsText) { _, value in module.setExcludedPaths(lines(value)) }
                    Text("Excluded application paths").font(DTTypography.body)
                    TextEditor(text: $appExclusionsText)
                        .font(DTTypography.monospacedBody)
                        .frame(minHeight: 56)
                        .overlay(RoundedRectangle(cornerRadius: DTRadius.sm).strokeBorder(DTColor.border))
                        .onChange(of: appExclusionsText) { _, value in module.setApplicationExcludedPaths(lines(value)) }
                }
            }

            SettingsSection(title: "Privacy and recovery", caption: "Usage history stays on this Mac. Local providers request no Full Disk Access; an executed web search is sent to the configured engine.") {
                HStack(spacing: DTSpace.sm) {
                    Button("Clear Usage History", role: .destructive) { module.clearHistory() }
                    Button("Restore Defaults") {
                        module.restoreDefaults()
                        syncTextFields()
                    }
                }
            }

            if !module.coordinator.diagnostics.isEmpty {
                SettingsSection(title: "Provider diagnostics", caption: "The palette stays usable with the remaining providers.") {
                    VStack(alignment: .leading, spacing: DTSpace.sm) {
                        ForEach(module.coordinator.diagnostics.values.sorted(by: { $0.provider.rawValue < $1.provider.rawValue }), id: \.provider.rawValue) { item in
                            Label("\(item.provider.displayName): \(item.message)", systemImage: "exclamationmark.triangle")
                                .font(DTTypography.caption)
                                .foregroundStyle(DTColor.warning)
                        }
                    }
                }
            }
        }
        .onAppear { syncTextFields() }
    }

    private func providerToggle(_ title: String, _ provider: PaletteProviderID, _ enabled: Bool) -> some View {
        Toggle(title, isOn: Binding(get: { enabled }, set: { module.setProvider(provider, enabled: $0) }))
    }

    private func applicationRow(_ application: ApplicationRecord) -> some View {
        HStack(spacing: DTSpace.sm) {
            if module.settings.applicationVisibility == .selected {
                Toggle(application.name, isOn: Binding(
                    get: { module.settings.selectedApplicationIDs.contains(application.id) },
                    set: { module.setApplicationVisible(application.id, visible: $0) }
                ))
                .toggleStyle(.checkbox)
            } else {
                Text(application.name).font(DTTypography.body)
            }
            Spacer()
            Button {
                let pinned = !module.settings.pinnedApplicationIDs.contains(application.id)
                module.setApplicationPinned(application.id, pinned: pinned)
            } label: {
                Image(systemName: module.settings.pinnedApplicationIDs.contains(application.id) ? "pin.fill" : "pin")
            }
            .buttonStyle(.plain)
            .help(module.settings.pinnedApplicationIDs.contains(application.id) ? "Unpin application" : "Pin application")
        }
        .padding(.horizontal, DTSpace.sm)
        .padding(.vertical, DTSpace.xs)
    }

    private func binding(_ keyPath: KeyPath<CommandPaletteSettings, Bool>, _ setter: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: { module.settings[keyPath: keyPath] }, set: setter)
    }

    private func lines(_ value: String) -> [String] {
        value.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func syncTextFields() {
        appLocationsText = module.settings.applicationLocations.joined(separator: "\n")
        appExclusionsText = module.settings.applicationExcludedPaths.joined(separator: "\n")
        exclusionsText = module.settings.excludedPaths.joined(separator: "\n")
    }
}
