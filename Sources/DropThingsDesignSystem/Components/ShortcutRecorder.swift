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
            Text(title)
                .font(DTTypography.body)
            Spacer()
            if isRecording {
                Text("Press a shortcut…")
                    .font(DTTypography.caption.monospaced())
                    .foregroundStyle(DTColor.accent)
                    .frame(minWidth: 180, alignment: .trailing)
            } else if let def = definition {
                Text(def.displayString)
                    .font(DTTypography.body.monospaced())
                    .foregroundStyle(DTColor.textPrimary)
                    .frame(minWidth: 180, alignment: .trailing)
            } else {
                Text("Not bound")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                    .frame(minWidth: 180, alignment: .trailing)
            }
            Button(isRecording ? "Cancel" : (definition == nil ? "Record" : "Re-record")) {
                if isRecording { stopRecording() } else { startRecording() }
            }
            .controlSize(.small)
            if !isRecording, definition != nil {
                Button("Clear", role: .destructive) {
                    definition = nil
                    onChange?(nil)
                }
                .controlSize(.small)
            }
        }
        .onDisappear { stopRecording() }
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
                modifiers: UInt32(mods.rawValue),
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
