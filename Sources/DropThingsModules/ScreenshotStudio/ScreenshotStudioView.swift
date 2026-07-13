import SwiftUI
import AppKit
import DropThingsDesignSystem
import DropThingsPlatform

struct ScreenshotStudioSettingsView: View {
    @ObservedObject var module: ScreenshotStudioModule

    var body: some View {
        SettingsSection(
            title: "Screenshot Studio",
            caption: "Capture a region, the window under the pointer, or the display under the pointer. Screen Recording is requested only when you enable or invoke this module."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                HStack(spacing: DTSpace.sm) {
                    ForEach(ScreenshotCaptureMode.allCases) { mode in
                        Button("Capture \(mode.title)") { module.capture(mode) }
                            .controlSize(.small)
                    }
                }

                Toggle("Enable global shortcuts", isOn: Binding(get: { module.settings.shortcutsEnabled }, set: { module.setShortcutsEnabled($0) }))

                ForEach(ScreenshotCaptureMode.allCases) { mode in
                    ShortcutRecorder(
                        title: "Capture \(mode.title)",
                        definition: Binding(get: { module.settings.shortcuts[mode] }, set: { module.setShortcut($0, for: mode) })
                    )
                }

                VStack(alignment: .leading, spacing: DTSpace.sm) {
                    Text("After each capture").font(DTTypography.sectionTitle)
                    ForEach(ScreenshotCaptureMode.allCases) { mode in
                        Picker("Capture \(mode.title)", selection: Binding(
                            get: { module.settings.output(for: mode) },
                            set: { module.setOutput($0, for: mode) }
                        )) {
                            ForEach(ScreenshotOutputAction.allCases) { Text($0.title).tag($0) }
                        }
                    }
                }

                Toggle(
                    "Show a visual preview after copied or saved captures",
                    isOn: Binding(get: { module.settings.showCapturePreview }, set: { module.setCapturePreviewVisible($0) })
                )
                Text("The preview confirms the capture and offers Edit and Pin. It is not needed when the selected action already opens the editor or preview.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)

                Picker("File format", selection: Binding(get: { module.settings.fileFormat }, set: { module.setFileFormat($0) })) {
                    ForEach(ScreenshotFileFormat.allCases) { Text($0.title).tag($0) }
                }
                if module.settings.fileFormat == .jpeg {
                    HStack {
                        Text("JPEG quality")
                        Slider(value: Binding(get: { module.settings.jpegQuality }, set: { module.setJPEGQuality($0) }), in: 0.1...1)
                        Text("\(Int(module.settings.jpegQuality * 100))%")
                            .font(DTTypography.caption).foregroundStyle(DTColor.textSecondary)
                    }
                }
                HStack {
                    Text("Thumbnail duration")
                    Slider(value: Binding(get: { module.settings.thumbnailDuration }, set: { module.setThumbnailDuration($0) }), in: 1...30, step: 1)
                    Text("\(Int(module.settings.thumbnailDuration)) s")
                        .font(DTTypography.caption).foregroundStyle(DTColor.textSecondary)
                }

                Toggle("Include window shadow when macOS provides it", isOn: Binding(get: { module.settings.includeWindowShadow }, set: { module.setIncludeWindowShadow($0) }))

                saveLocation

                if let size = module.lastCaptureSize {
                    Text("Last capture: \(Int(size.width)) × \(Int(size.height)) px")
                        .font(DTTypography.caption).foregroundStyle(DTColor.textSecondary)
                }
                if let url = module.lastSavedURL {
                    HStack {
                        Text("Last saved: \(url.lastPathComponent)").font(DTTypography.caption).lineLimit(1)
                        Spacer()
                        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }.controlSize(.small)
                    }
                }
            }
        }
    }

    private var saveLocation: some View {
        HStack(spacing: DTSpace.sm) {
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text("Save location").font(DTTypography.body)
                Text(module.settings.saveLocationPath ?? "Desktop").font(DTTypography.caption).foregroundStyle(DTColor.textSecondary).lineLimit(1)
            }
            Spacer()
            Button("Choose…") { chooseSaveLocation() }.controlSize(.small)
        }
    }

    private func chooseSaveLocation() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; panel.prompt = "Choose"
        if let path = module.settings.saveLocationPath { panel.directoryURL = URL(fileURLWithPath: path) }
        guard panel.runModal() == .OK else { return }
        module.setSaveLocation(panel.url)
    }
}
