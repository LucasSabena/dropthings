import SwiftUI
import AppKit
import DropThingsPlatform

/// Records a new keyboard shortcut from the user. When active, captures
/// the next `keyDown` via a local NSEvent monitor; rejects shortcuts with
/// no modifier; stops on ESC or on a valid capture. Calls `onChange` with
/// the new `Definition`, or `nil` if the user cleared the binding.
public struct ShortcutRecorder: View {
    public let title: String
    @Binding public var definition: GlobalHotkey.Definition?
    public var onChange: ((GlobalHotkey.Definition?) -> Void)?

    @State private var isRecording = false
    @State private var monitor: Any?

    public init(
        title: String,
        definition: Binding<GlobalHotkey.Definition?>,
        onChange: ((GlobalHotkey.Definition?) -> Void)? = nil
    ) {
        self.title = title
        self._definition = definition
        self.onChange = onChange
    }

    public var body: some View {
        HStack(spacing: DTSpace.sm) {
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(title)
                    .font(DTTypography.body)
                Text(isRecording ? "Press the new shortcut now" : "Current shortcut")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
            Spacer()

            shortcutBadge

            Button {
                if isRecording { stopRecording() } else { startRecording() }
            } label: {
                Label(isRecording ? "Cancel" : "Change", systemImage: isRecording ? "xmark" : "keyboard")
            }
            .controlSize(.small)

            if !isRecording, definition != nil {
                Button(role: .destructive) {
                    definition = nil
                    onChange?(nil)
                } label: {
                    Image(systemName: "trash")
                }
                .controlSize(.small)
                .help("Clear shortcut")
            }
        }
        .onDisappear { stopRecording() }
    }

    @ViewBuilder
    private var shortcutBadge: some View {
        if isRecording {
            Text("Recording")
                .font(DTTypography.caption.monospaced())
                .foregroundStyle(DTColor.accent)
                .padding(.horizontal, DTSpace.sm)
                .padding(.vertical, DTSpace.xs)
                .frame(minWidth: 110)
                .background(DTColor.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous))
        } else if let def = definition {
            Text(def.displayString)
                .font(DTTypography.body.monospaced().weight(.semibold))
                .foregroundStyle(DTColor.textPrimary)
                .padding(.horizontal, DTSpace.sm)
                .padding(.vertical, DTSpace.xs)
                .frame(minWidth: 110)
                .background(DTColor.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous)
                        .strokeBorder(DTColor.border, lineWidth: 0.5)
                )
        } else {
            Text("None")
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
                .padding(.horizontal, DTSpace.sm)
                .padding(.vertical, DTSpace.xs)
                .frame(minWidth: 110)
                .background(DTColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous)
                        .strokeBorder(DTColor.border, lineWidth: 0.5)
                )
        }
    }

    private func startRecording() {
        isRecording = true
        let previousID = definition?.id ?? 0
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ESC cancels.
            if event.keyCode == 53 {
                Task { @MainActor in stopRecording() }
                return nil
            }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let required: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            // Reject bare keys without a modifier.
            if mods.intersection(required).isEmpty {
                return nil
            }
            let newDef = GlobalHotkey.Definition(
                keyCode: UInt32(event.keyCode),
                modifiers: GlobalHotkey.Definition.carbonModifiers(from: mods),
                id: previousID == 0 ? UInt32.random(in: 100...UInt32.max) : previousID
            )
            Task { @MainActor in
                definition = newDef
                onChange?(newDef)
                stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
