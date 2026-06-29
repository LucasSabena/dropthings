import SwiftUI
import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct ScreenshotRegionSettingsView: View {
    @ObservedObject var module: ScreenshotRegionModule

    var body: some View {
        SettingsSection(
            title: "Screenshot Region",
            caption: "Drag to select any area of your screen. ESC cancels, Enter confirms. Captures are saved to the location you choose and a preview is copied to your clipboard."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Button {
                    module.captureRegion()
                } label: {
                    Label("Capture region now", systemImage: "camera.viewfinder")
                }
                .controlSize(.regular)

                Toggle("Enable hotkey", isOn: Binding(
                    get: { module.screenshotRegionSettings.hotkeyEnabled },
                    set: { module.setHotkeyEnabled($0) }
                ))

                ShortcutRecorder(
                    title: "Capture region",
                    definition: Binding(
                        get: { module.screenshotRegionSettings.hotkey },
                        set: { module.setHotkey($0) }
                    )
                )

                saveLocationRow

                Toggle("Copy preview to pasteboard", isOn: Binding(
                    get: { module.screenshotRegionSettings.copyPreviewToPasteboard },
                    set: { module.setCopyPreviewToPasteboard($0) }
                ))

                if let url = module.lastSavedURL {
                    HStack {
                        Text("Last saved: \(url.lastPathComponent)")
                            .font(DTTypography.caption)
                            .foregroundStyle(DTColor.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private var saveLocationRow: some View {
        HStack(spacing: DTSpace.sm) {
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text("Save location")
                    .font(DTTypography.body)
                Text(displaySaveLocation)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Choose…") {
                chooseSaveLocation()
            }
            .controlSize(.small)
        }
    }

    private var displaySaveLocation: String {
        if let path = module.screenshotRegionSettings.saveLocationPath {
            return path
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path
            ?? "Desktop"
    }

    private func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select a folder for saved screenshots"
        if let path = module.screenshotRegionSettings.saveLocationPath {
            panel.directoryURL = URL(fileURLWithPath: path)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        module.setSaveLocation(url)
    }
}
