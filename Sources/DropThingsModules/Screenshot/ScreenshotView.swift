import SwiftUI
import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct ScreenshotSettingsView: View {
    @ObservedObject var module: ScreenshotModule

    var body: some View {
        SettingsSection(
            title: "Screenshot",
            caption: "Capture the screen with the hotkey or the button below. Default folder is ~/Downloads/Screenshots; pick another if you prefer."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Button {
                    module.captureFullScreen()
                } label: {
                    Label("Capture screen now", systemImage: "camera.viewfinder")
                }
                .controlSize(.regular)

                Toggle("Enable hotkey", isOn: Binding(
                    get: { module.screenshotSettings.hotkeyEnabled },
                    set: { module.setHotkeyEnabled($0) }
                ))

                ShortcutRecorder(
                    title: "Capture",
                    definition: Binding(
                        get: { module.screenshotSettings.hotkey },
                        set: { module.setHotkey($0) }
                    )
                )

                HStack {
                    Text("Save folder:")
                        .font(DTTypography.body)
                    Spacer()
                    Text(module.screenshotSettings.lastSavePath ?? "~/Downloads/Screenshots")
                        .font(DTTypography.caption.monospaced())
                        .foregroundStyle(DTColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose…") {
                        module.chooseSaveFolder()
                    }
                    .controlSize(.small)
                }

                if let url = module.lastSavedURL {
                    HStack(spacing: DTSpace.xs) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(DTColor.success)
                        Text("Saved ")
                            .font(DTTypography.caption)
                            .foregroundStyle(DTColor.textSecondary)
                        + Text(url.path)
                            .font(DTTypography.caption.monospaced())
                            .foregroundStyle(DTColor.textSecondary)
                    }
                }
            }
        }
    }
}

struct ScreenshotResultView: View {
    let image: CGImage
    let onSave: () -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    onCopy()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                Button {
                    onSave()
                } label: {
                    Label("Save…", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(DTSpace.md)
            Divider()
            Image(nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(DTSpace.md)
        }
        .background(DTColor.background)
    }
}
