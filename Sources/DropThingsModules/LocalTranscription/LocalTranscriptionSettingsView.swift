import SwiftUI
import DropThingsDesignSystem
import DropThingsTranscriptionKit

struct LocalTranscriptionSettingsView: View {
    @ObservedObject var module: LocalTranscriptionModule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DTSpace.xl) {
                SettingsSection(
                    title: "Workspace",
                    caption: "File transcription is local and does not require microphone access."
                ) {
                    HStack {
                        VStack(alignment: .leading, spacing: DTSpace.xxs) {
                            Text("Transcription queue")
                                .font(DTTypography.body)
                            Text("Accepts common audio and video formats and normalizes them locally before transcription.")
                                .font(DTTypography.caption)
                                .foregroundStyle(DTColor.textSecondary)
                        }
                        Spacer()
                        Button("Open Workspace") { module.openWorkspace() }
                    }
                }

                TranscriptionOptionsView(module: module)
                ModelManagementView(module: module)

                if let notice = module.notice {
                    InlineAlert(style: .info, message: notice)
                }
            }
            .padding(DTSpace.xl)
            .frame(maxWidth: DTSize.contentMaxWidth, alignment: .leading)
        }
    }
}

struct TranscriptionOptionsView: View {
    @ObservedObject var module: LocalTranscriptionModule

    var body: some View {
        SettingsSection(title: "Defaults", caption: "Applied when a queued file starts.") {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Picker("Model", selection: modelBinding) {
                    ForEach(CuratedTranscriptionModels.all) { descriptor in
                        Text(descriptor.displayName).tag(descriptor.id)
                    }
                }
                Picker("Language", selection: languageBinding) {
                    ForEach(TranscriptionLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                Picker("Task", selection: modeBinding) {
                    Text("Transcribe").tag(TranscriptionMode.transcribe)
                    Text("Translate to English").tag(TranscriptionMode.translateToEnglish)
                }
                HStack {
                    Text("Outputs")
                    Toggle("TXT", isOn: formatBinding(.text))
                    Toggle("JSON", isOn: formatBinding(.json))
                }
                TextField("Optional vocabulary prompt", text: promptBinding, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var modelBinding: Binding<TranscriptionModelID> {
        Binding(get: { module.settings.selectedModel }, set: { value in
            module.updateSettings { $0.selectedModel = value }
        })
    }

    private var languageBinding: Binding<TranscriptionLanguage> {
        Binding(get: { module.settings.language }, set: { value in
            module.updateSettings { $0.language = value }
        })
    }

    private var modeBinding: Binding<TranscriptionMode> {
        Binding(get: { module.settings.mode }, set: { value in
            module.updateSettings { $0.mode = value }
        })
    }

    private var promptBinding: Binding<String> {
        Binding(get: { module.settings.initialPrompt }, set: { value in
            module.updateSettings { $0.initialPrompt = value }
        })
    }

    private func formatBinding(_ format: TranscriptOutputFormat) -> Binding<Bool> {
        Binding(
            get: { module.settings.outputFormats.contains(format) },
            set: { enabled in
                module.updateSettings {
                    if enabled { $0.outputFormats.insert(format) }
                    else { $0.outputFormats.remove(format) }
                }
            }
        )
    }
}

private struct ModelManagementView: View {
    @ObservedObject var module: LocalTranscriptionModule

    var body: some View {
        SettingsSection(
            title: "Models",
            caption: "Downloads contact Hugging Face only after you click Download. Every file is size- and SHA-256-verified."
        ) {
            VStack(spacing: DTSpace.sm) {
                ForEach(CuratedTranscriptionModels.all) { descriptor in
                    HStack(alignment: .top, spacing: DTSpace.md) {
                        VStack(alignment: .leading, spacing: DTSpace.xxs) {
                            Text(descriptor.displayName).font(DTTypography.body.weight(.semibold))
                            Text(descriptor.memoryGuidance)
                                .font(DTTypography.caption)
                                .foregroundStyle(DTColor.textSecondary)
                        }
                        Spacer()
                        if module.installedModels.contains(descriptor.id) {
                            Text("Installed").foregroundStyle(DTColor.success)
                            Button("Remove") { module.deleteModel(descriptor.id) }
                                .disabled(module.modelOperation != nil)
                        } else if module.modelOperation == descriptor.id {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Import…") { module.importModel(descriptor.id) }
                                .disabled(module.modelOperation != nil)
                            Button("Download") { module.downloadModel(descriptor.id) }
                                .disabled(module.modelOperation != nil)
                        }
                    }
                    if descriptor.id != CuratedTranscriptionModels.all.last?.id { Divider() }
                }
            }
        }
    }
}
