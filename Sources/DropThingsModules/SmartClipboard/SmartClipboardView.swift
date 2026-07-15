import SwiftUI
import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct SmartClipboardPanelView: View {
    @ObservedObject var module: SmartClipboardModule
    let controller: SmartClipboardPanelController
    @State private var selectedActionID: String?
    @State private var outcome: SmartClipboardModule.ActionOutcome?
    @State private var fetchingTitle = false
    @State private var didCopy = false
    @State private var pasteBackResult: SmartClipboardModule.PasteBackResult?
    @State private var undoResult: SmartClipboardModule.UndoResult?

    private var snapshot: SmartClipboardSnapshot? { module.currentSnapshot() }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            previewSection
            Divider()
            actionsSection
            Divider()
            statusBar
        }
        .background(DTColor.background)
        .onAppear {
            module.refreshSnapshot()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DTSpace.md) {
            if let snapshot {
                Image(systemName: snapshot.kind.systemImage)
                    .font(DTTypography.moduleHeaderIcon)
                    .foregroundStyle(DTColor.accent)
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    Text("Smart Clipboard")
                        .font(DTTypography.windowTitle)
                    Text(snapshot.kind.label)
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                }
            } else {
                Image(systemName: "clipboard.fill")
                    .font(DTTypography.moduleHeaderIcon)
                    .foregroundStyle(DTColor.textSecondary)
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    Text("Smart Clipboard")
                        .font(DTTypography.windowTitle)
                    Text("Copy something to see actions.")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                }
            }
            Spacer()
            treatAsMenu
            Button {
                module.refreshSnapshot()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh from clipboard")
            .accessibilityLabel("Refresh from clipboard")
        }
        .padding(.horizontal, DTSpace.lg)
        .padding(.vertical, DTSpace.md)
    }

    @ViewBuilder
    private var treatAsMenu: some View {
        Menu {
            Button("Auto-detect") {
                controller.forcedKind = nil
                module.refreshSnapshot()
            }
            Divider()
            ForEach(allTreatAsKinds, id: \.self) { kind in
                Button(kind.label) {
                    controller.forcedKind = kind
                    module.refreshSnapshot()
                }
            }
        } label: {
            Label("Treat As", systemImage: "square.and.pencil")
                .font(DTTypography.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var allTreatAsKinds: [SmartClipboardKind] {
        // Text-compatible overrides plus the detected ones. Ambiguous text
        // can always be forced back to text, URL, JSON, or color.
        [.text, .url, .json, .color]
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewSection: some View {
        if let snapshot {
            VStack(alignment: .leading, spacing: DTSpace.sm) {
                previewBody(for: snapshot)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let notice = outcome?.notice {
                    InlineAlert(style: .info, message: notice)
                }
            }
            .padding(DTSpace.lg)
        } else {
            VStack(spacing: DTSpace.sm) {
                Image(systemName: "doc.on.clipboard")
                    .font(DTTypography.emptyStateGlyph)
                    .foregroundStyle(DTColor.textTertiary)
                Text("Nothing to act on yet. Copy text, a URL, JSON, a color, or files.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(DTSpace.lg)
        }
    }

    @ViewBuilder
    private func previewBody(for snapshot: SmartClipboardSnapshot) -> some View {
        let hide = module.smartClipboardSettings.hideSensitivePreview
        switch snapshot.kind {
        case .text, .url, .json:
            TextEditor(text: .constant(hide ? "Preview hidden" : previewText(for: snapshot)))
                .font(DTTypography.monospacedBody)
                .scrollContentBackground(.hidden)
                .background(hide ? DTColor.surfaceRaised : DTColor.surface)
                .disabled(hide)
                .frame(minHeight: 120, maxHeight: .infinity)
        case .color:
            if let color = snapshot.color {
                ColorPreview(color: color, format: module.smartClipboardSettings.colorFormat, hidden: hide)
            } else {
                Text(snapshot.colorHex ?? "")
                    .font(DTTypography.monospacedBody)
                    .foregroundStyle(DTColor.textPrimary)
            }
        case .files:
            FilesPreview(urls: snapshot.fileURLs)
        case .image:
            ImagePreview(imageData: snapshot.imageData, hidden: hide)
        }
    }

    private func previewText(for snapshot: SmartClipboardSnapshot) -> String {
        if let outcome { return outcome.preview }
        return snapshot.text ?? ""
    }

    // MARK: - Actions

    private var actions: [SmartClipboardAction] {
        guard let snapshot else { return [] }
        return SmartClipboardActionRegistry.actions(
            for: snapshot.kind,
            fileActions: module.availableFileActions(),
            canFetchTitle: true
        )
    }

    @ViewBuilder
    private var actionsSection: some View {
        if snapshot == nil {
            EmptyView()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DTSpace.xxs) {
                    ForEach(actions) { action in
                        actionRow(action)
                    }
                }
                .padding(.horizontal, DTSpace.lg)
                .padding(.vertical, DTSpace.md)
            }
        }
    }

    private func actionRow(_ action: SmartClipboardAction) -> some View {
        let pinned = module.pinnedActionIDs.contains(action.id)
        return HStack(spacing: DTSpace.sm) {
            Button {
                runAction(action)
            } label: {
                HStack(spacing: DTSpace.sm) {
                    Image(systemName: action.systemImage)
                        .frame(width: 20)
                        .foregroundStyle(DTColor.accent)
                    Text(action.title)
                        .font(DTTypography.body)
                        .foregroundStyle(DTColor.textPrimary)
                    Spacer()
                    if pinned {
                        Image(systemName: "pin.fill")
                            .font(DTTypography.badgeLabel)
                            .foregroundStyle(DTColor.warning)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(action.title)
            .contextMenu {
                Button(pinned ? "Unpin" : "Pin") {
                    module.togglePinned(actionID: action.id)
                }
            }
        }
        .padding(.vertical, DTSpace.xs)
        .padding(.horizontal, DTSpace.sm)
        .background(DTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous))
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: DTSpace.sm) {
            if didCopy {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.success)
            }
            if fetchingTitle {
                Label("Fetching…", systemImage: "network")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
            if let pasteBackResult {
                Text(pasteBackLabel(pasteBackResult))
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
            if let undoResult, undoResult == .restored {
                Label("Restored previous clipboard", systemImage: "arrow.uturn.backward")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.success)
            }
            Spacer()
            Button {
                module.undoCopy()
                undoResult = .restored
            } label: {
                Label("Undo copy", systemImage: "arrow.uturn.backward")
            }
            .controlSize(.small)
            .disabled(module.lastResult == nil)

            if module.smartClipboardSettings.pasteBackEnabled {
                Button {
                    pasteBackResult = module.pasteBack()
                } label: {
                    Label("Paste", systemImage: "arrow.down.doc")
                }
                .controlSize(.small)
                .disabled(outcome?.copyableText == nil)
            }
        }
        .padding(.horizontal, DTSpace.lg)
        .padding(.vertical, DTSpace.sm)
    }

    private func pasteBackLabel(_ result: SmartClipboardModule.PasteBackResult) -> String {
        switch result {
        case .pasted: return "Pasted"
        case .disabled: return "Paste-back is off"
        case .needsAccessibility: return "Paste-back needs Accessibility"
        case .nothingToPaste: return "Nothing to paste"
        }
    }

    // MARK: - Actions

    private func runAction(_ action: SmartClipboardAction) {
        guard let snapshot else { return }
        if case .urlTitleFetch = action.body {
            Task { @MainActor in
                fetchingTitle = true
                let result = await module.fetchURLTitle(for: snapshot)
                outcome = result
                fetchingTitle = false
            }
            return
        }
        let result = module.apply(action: action, to: snapshot)
        outcome = result
        switch action.body {
        case .filesReveal:
            module.revealInFinder(for: snapshot)
        case .filesSaveRepresentation:
            module.saveImageRepresentation(for: snapshot)
        case .filesAction(let ref):
            let ran = module.runFileAction(id: ref.id, for: snapshot)
            if !ran {
                outcome = SmartClipboardModule.ActionOutcome(
                    preview: outcome?.preview ?? "",
                    copyableText: outcome?.copyableText,
                    notice: "\(ref.title) is not available right now."
                )
            }
        default:
            break
        }
        // Copy-only actions with a copyable text commit immediately so the
        // user can paste without an extra step.
        if let text = result.copyableText {
            module.copyResult(text)
            didCopy = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { didCopy = false }
        }
    }
}

// MARK: - Preview subviews

private struct ColorPreview: View {
    let color: SmartClipboardColor
    let format: SmartClipboardColorFormat
    let hidden: Bool

    var body: some View {
        HStack(spacing: DTSpace.md) {
            if hidden {
                Rectangle().fill(DTColor.surfaceRaised).frame(width: 72, height: 72)
            } else if let nsColor = color.nsColor {
                Rectangle().fill(Color(nsColor: nsColor)).frame(width: 72, height: 72)
                    .overlay(RoundedRectangle(cornerRadius: DTRadius.md).stroke(DTColor.border, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: DTSpace.xs) {
                Text(format.string(from: color))
                    .font(DTTypography.monospacedBody)
                    .foregroundStyle(DTColor.textPrimary)
                Text("\(color.r), \(color.g), \(color.b) · α \(color.a)")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
        }
        .padding(DTSpace.md)
        .background(DTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
    }
}

private struct FilesPreview: View {
    let urls: [URL]

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.xs) {
            ForEach(urls, id: \.self) { url in
                let info = FileContentInfo.inspect(url)
                HStack(spacing: DTSpace.sm) {
                    Image(systemName: info.kind.systemImageName)
                        .foregroundStyle(DTColor.accent)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: DTSpace.xxs) {
                        Text(url.lastPathComponent).font(DTTypography.body)
                            .lineLimit(1)
                        Text(url.path)
                            .font(DTTypography.caption)
                            .foregroundStyle(DTColor.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let size = info.byteCount {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(DTTypography.caption.monospaced())
                            .foregroundStyle(DTColor.textSecondary)
                    }
                }
            }
        }
        .padding(DTSpace.md)
        .background(DTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
    }
}

private struct ImagePreview: View {
    let imageData: Data?
    let hidden: Bool

    var body: some View {
        Group {
            if hidden {
                Rectangle().fill(DTColor.surfaceRaised)
                    .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 200)
                    .overlay(
                        Text("Preview hidden")
                            .font(DTTypography.caption)
                            .foregroundStyle(DTColor.textSecondary)
                    )
            } else if let data = imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 200)
            } else {
                Text("No image data")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
        }
        .padding(DTSpace.md)
    }
}

// MARK: - Settings view

struct SmartClipboardSettingsView: View {
    @ObservedObject var module: SmartClipboardModule

    var body: some View {
        SettingsSection(
            title: "Smart Clipboard",
            caption: "Content-aware actions for the current clipboard. Everything runs locally; network access is only the explicit page-title fetch."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                Button {
                    module.showPanel()
                } label: {
                    Label("Open Smart Clipboard", systemImage: module.iconName)
                }

                Toggle("Enable hotkey", isOn: Binding(
                    get: { module.smartClipboardSettings.hotkeyEnabled },
                    set: { module.setHotkeyEnabled($0) }
                ))

                ShortcutRecorder(
                    title: "Open Smart Clipboard",
                    definition: Binding(
                        get: { module.smartClipboardSettings.hotkey },
                        set: { module.setHotkey($0) }
                    )
                )

                HStack {
                    Text("Default color format")
                        .font(DTTypography.body)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { module.smartClipboardSettings.colorFormat },
                        set: { module.setColorFormat($0) }
                    )) {
                        ForEach(SmartClipboardColorFormat.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 160)
                }

                Toggle("Hide sensitive preview", isOn: Binding(
                    get: { module.smartClipboardSettings.hideSensitivePreview },
                    set: { module.setHideSensitivePreview($0) }
                ))
                .help("Hide text and image previews while the panel is focused.")

                Toggle("Paste back into previous app", isOn: Binding(
                    get: { module.smartClipboardSettings.pasteBackEnabled },
                    set: { module.setPasteBackEnabled($0) }
                ))
                .help("Requires Accessibility. When on, Paste copies the result and sends ⌘V to the app that had focus before the panel opened.")

                HStack {
                    Text("Undo-copy window: \(module.smartClipboardSettings.undoCopyWindowSeconds)s")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                    Spacer()
                    Stepper("", value: Binding(
                        get: { module.smartClipboardSettings.undoCopyWindowSeconds },
                        set: { module.setUndoCopyWindow(seconds: $0) }
                    ), in: 0...300)
                    .labelsHidden()
                }
            }
        }
    }
}