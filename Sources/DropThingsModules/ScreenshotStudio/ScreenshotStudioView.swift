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
                Toggle("Enable global shortcuts", isOn: Binding(get: { module.settings.shortcutsEnabled }, set: { module.setShortcutsEnabled($0) }))

                VStack(alignment: .leading, spacing: DTSpace.sm) {
                    Text("Capture shortcuts").font(DTTypography.sectionTitle)
                    Text("Each row is a complete workflow: choose its shortcut and what happens after capture.")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                    ForEach(ScreenshotShortcutSlot.allCases) { slot in
                        ScreenshotShortcutRow(module: module, slot: slot)
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

private struct ScreenshotShortcutRow: View {
    @ObservedObject var module: ScreenshotStudioModule
    let slot: ScreenshotShortcutSlot

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.sm) {
            HStack(spacing: DTSpace.md) {
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    Text(slot.title).font(DTTypography.body.weight(.semibold))
                    Text(slot.mode == .scrolling ? "Select a fixed viewport, then DropThings scrolls and stitches it." : "Captures from the display under the pointer.")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                }
                Spacer()
                Picker("Result", selection: Binding(
                    get: { module.settings.output(forShortcut: slot) },
                    set: { module.setOutput($0, for: slot) }
                )) {
                    ForEach(ScreenshotOutputAction.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 155)
            }
            ShortcutRecorder(
                title: "Shortcut",
                definition: Binding(get: { module.settings.shortcuts[slot] }, set: { module.setShortcut($0, for: slot) })
            )
        }
        .padding(DTSpace.md)
        .background(DTColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DTRadius.md).strokeBorder(DTColor.border))
    }
}

struct ScreenshotStudioMenuBarView: View {
    @ObservedObject var module: ScreenshotStudioModule

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            Text("New capture")
                .font(DTTypography.sectionTitle)
                .padding(.horizontal, DTSpace.md)
                .padding(.top, DTSpace.md)
            ForEach(ScreenshotShortcutSlot.allCases) { slot in
                Button {
                    module.captureShortcut(slot)
                } label: {
                    HStack {
                        Label(slot.title, systemImage: symbol(for: slot.mode))
                        Spacer()
                        if let shortcut = module.settings.shortcuts[slot] {
                            Text(shortcut.displayString)
                                .foregroundStyle(DTColor.textSecondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DTSpace.md)
                .padding(.vertical, DTSpace.sm)
            }
            Spacer(minLength: 0)
        }
        .background(.regularMaterial)
    }

    private func symbol(for mode: ScreenshotCaptureMode) -> String {
        switch mode {
        case .region: return "viewfinder"
        case .window: return "macwindow"
        case .display: return "display"
        case .scrolling: return "scroll"
        }
    }
}
