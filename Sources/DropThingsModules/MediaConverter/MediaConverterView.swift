import AppKit
import SwiftUI
import UniformTypeIdentifiers
import DropThingsCore
import DropThingsDesignSystem
import DropThingsMediaConverterKit

/// Settings/detail surface for Media Converter. The first screen is usable
/// immediately: drop/select media to convert. Simple mode is outcome-oriented;
/// Advanced mode exposes typed, capability-driven controls.
struct MediaConverterSettingsView: View {
    @ObservedObject var module: MediaConverterModule
    @State private var advanced: Bool

    init(module: MediaConverterModule) {
        self.module = module
        // Seed from persisted preference so Advanced users get Advanced on reopen.
        _advanced = State(initialValue: module.settings.startInAdvancedMode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.lg) {
            SettingsSection(
                title: "Media Converter",
                caption: "Convert, resize and compress images, audio and video locally. Your files never leave this Mac."
            ) {
                VStack(alignment: .leading, spacing: DTSpace.md) {
                    Picker("Mode", selection: $advanced) {
                        Text("Simple").tag(false)
                        Text("Advanced").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: advanced) { _, value in module.setStartInAdvanced(value) }

                    if !module.ffmpegAvailable {
                        InlineAlert(
                            style: .warning,
                            message: module.ffmpegReason ?? "Audio and video conversion need the bundled media engine, which isn't packaged in this build."
                        )
                    }

                    MediaConverterDropZone(module: module, advanced: advanced)

                    if !module.queue.items.isEmpty {
                        MediaQueueList(module: module)
                    }
                }
            }

            AdvancedControls(module: module)
                .opacity(advanced ? 1 : 0.5)
                .disabled(!advanced)
        }
    }
}

/// Advanced defaults. Kept separate so Simple mode reads cleanly.
private struct AdvancedControls: View {
    @ObservedObject var module: MediaConverterModule

    var body: some View {
        SettingsSection(title: "Defaults", caption: "Applied to new conversions.") {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Picker("On conflict", selection: Binding(
                    get: { module.settings.conflict },
                    set: { module.setConflict($0) }
                )) {
                    Text("Add a suffix").tag(ConflictPolicy.suffix)
                    Text("Skip").tag(ConflictPolicy.skip)
                    Text("Ask").tag(ConflictPolicy.fail)
                }

                Picker("Metadata", selection: Binding(
                    get: { module.settings.metadata },
                    set: { module.setMetadata($0) }
                )) {
                    Text("Preserve").tag(MetadataPolicy.preserve)
                    Text("Remove location").tag(MetadataPolicy.removeLocationOnly)
                    Text("Strip nonessential").tag(MetadataPolicy.stripNonessential)
                }

                Toggle("Never upscale images", isOn: Binding(
                    get: { module.settings.noUpscaleByDefault },
                    set: { module.setNoUpscaleDefault($0) }
                ))

                HStack {
                    VStack(alignment: .leading, spacing: DTSpace.xxs) {
                        Text("Output folder")
                            .font(DTTypography.body)
                        Text(module.settings.outputDirectory?.path ?? "Same folder as each source")
                            .font(DTTypography.caption)
                            .foregroundStyle(DTColor.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    if module.settings.outputDirectory != nil {
                        Button("Use Source Folder") { module.setOutputDirectory(nil) }
                            .controlSize(.small)
                    }
                    Button("Choose…") { chooseOutputFolder() }
                        .controlSize(.small)
                }
            }
        }
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Conversion Output Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return }
        module.setOutputDirectory(panel.url)
    }
}
