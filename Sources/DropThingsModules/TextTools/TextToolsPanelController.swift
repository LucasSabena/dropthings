import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

/// Floating panel for the Text Tools module. Keeps AppKit window behavior in
/// one place so the module and the SwiftUI view stay focused on feature logic.
final class TextToolsPanelController {
    private var panel: NSPanel?
    private weak var module: TextToolsModule?

    init(module: TextToolsModule) {
        self.module = module
    }

    func show() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            panel.title = "Text Tools"
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isReleasedWhenClosed = false
            panel.minSize = NSSize(width: 360, height: 280)
            panel.contentView = NSHostingView(rootView: AnyView(EmptyView()))
            self.panel = panel
        }
        refreshContent()
        panel?.center()
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        guard let panel, panel.isVisible else {
            show()
            return
        }
        hide()
    }

    private func refreshContent() {
        guard let module, let panel else { return }
        let root = AnyView(
            TextToolsPanelView(module: module)
                .frame(minWidth: 360, minHeight: 280)
        )
        (panel.contentView as? NSHostingView<AnyView>)?.rootView = root
    }
}

struct TextToolsPanelView: View {
    @ObservedObject var module: TextToolsModule
    @State private var text: String = ""
    @State private var selectedTransform: TextToolsEngine.Transform = .uppercase
    @State private var didCopyOutput = false

    private var counts: TextToolsEngine.Counts {
        TextToolsEngine.counts(for: text)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            editor
            Divider()
            statusBar
        }
        .background(DTColor.background)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DTSpace.xs) {
                transformButton(.uppercase)
                transformButton(.lowercase)
                transformButton(.titleCase)
                transformButton(.camelCase)
                transformButton(.snakeCase)

                Divider()
                    .frame(height: 20)

                transformButton(.urlEncode)
                transformButton(.urlDecode)
                transformButton(.jsonPretty)
                transformButton(.jsonMinify)
                transformButton(.base64Encode)
                transformButton(.base64Decode)

                Divider()
                    .frame(height: 20)

                transformButton(.sortLines)
                transformButton(.removeDuplicateLines)
            }
            .padding(.horizontal, DTSpace.sm)
            .padding(.vertical, DTSpace.sm)
        }
    }

    private func transformButton(_ transform: TextToolsEngine.Transform) -> some View {
        Button {
            apply(transform)
        } label: {
            Label(transform.label, systemImage: transform.systemImage)
                .font(DTTypography.caption)
        }
        .controlSize(.small)
        .buttonStyle(.borderedProminent)
        .tint(selectedTransform == transform ? DTColor.accent : DTColor.surfaceRaised)
        .foregroundStyle(selectedTransform == transform ? Color.white : DTColor.textPrimary)
        .help(transform.label)
    }

    // MARK: - Editor

    private var editor: some View {
        TextEditor(text: $text)
            .font(DTTypography.monospacedBody)
            .scrollContentBackground(.hidden)
            .background(DTColor.surfaceRaised)
            .padding(DTSpace.xs)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: DTSpace.md) {
            HStack(spacing: DTSpace.sm) {
                statLabel("\(counts.characters) chars")
                statLabel("\(counts.words) words")
                statLabel("\(counts.lines) lines")
            }

            Spacer()

            HStack(spacing: DTSpace.sm) {
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .controlSize(.small)

                Button {
                    copyToClipboard(text)
                } label: {
                    Label(didCopyOutput ? "Copied" : "Copy", systemImage: didCopyOutput ? "checkmark" : "doc.on.doc")
                }
                .controlSize(.small)
                .disabled(text.isEmpty)

                Button {
                    text = ""
                } label: {
                    Label("Clear", systemImage: "xmark")
                }
                .controlSize(.small)
                .disabled(text.isEmpty)
            }
        }
        .padding(.horizontal, DTSpace.md)
        .padding(.vertical, DTSpace.sm)
    }

    private func statLabel(_ value: String) -> some View {
        Text(value)
            .font(DTTypography.caption.monospaced())
            .foregroundStyle(DTColor.textSecondary)
    }

    // MARK: - Actions

    private func apply(_ transform: TextToolsEngine.Transform) {
        selectedTransform = transform
        text = TextToolsEngine.apply(transform, to: text)
    }

    private func copyToClipboard(_ value: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
        didCopyOutput = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            didCopyOutput = false
        }
    }

    private func pasteFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        text = string
    }
}
