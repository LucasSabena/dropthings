import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

/// Floating panel for the Command Palette. Shows a searchable list of commands
/// from all modules with keyboard navigation.
@MainActor
final class CommandPalettePanelController {
    private var panel: NSPanel?
    private let commandSource: @MainActor () -> [CommandDescriptor]

    init(commandSource: @escaping @MainActor () -> [CommandDescriptor]) {
        self.commandSource = commandSource
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func show() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
                styleMask: [.titled, .closable, .nonactivatingPanel, .resizable],
                backing: .buffered,
                defer: false
            )
            panel.title = "Command Palette"
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isReleasedWhenClosed = false
            panel.minSize = NSSize(width: 360, height: 240)
            panel.contentView = NSHostingView(rootView: AnyView(EmptyView()))
            self.panel = panel
        }
        refreshContent()
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func refreshContent() {
        guard let panel else { return }
        let root = AnyView(
            CommandPalettePanelView(
                commands: commandSource(),
                onClose: { [weak self] in self?.hide() }
            )
                .frame(minWidth: 360, minHeight: 240)
        )
        (panel.contentView as? NSHostingView<AnyView>)?.rootView = root
    }
}

struct CommandPalettePanelView: View {
    let commands: [CommandDescriptor]
    let onClose: () -> Void

    @State private var searchText = ""
    @State private var selection: String?
    @State private var eventMonitor: Any?

    private var filteredCommands: [CommandDescriptor] {
        CommandPaletteFilter.filter(commands, query: searchText)
    }

    var body: some View {
        VStack(spacing: DTSpace.sm) {
            searchField

            if filteredCommands.isEmpty {
                Spacer()
                Text(searchText.isEmpty ? "No commands available." : "No matching commands.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                Spacer()
            } else {
                List(filteredCommands) { command in
                    CommandPaletteRow(
                        command: command,
                        isSelected: selection == command.id,
                        onExecute: { execute(command) }
                    )
                }
                .listStyle(.plain)
            }

            HStack {
                Text("\(filteredCommands.count) command\(filteredCommands.count == 1 ? "" : "s")")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                Spacer()
                Text("↑↓ to navigate · ↩ to run · ⎋ to close")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
            .padding(.horizontal, DTSpace.md)
            .padding(.bottom, DTSpace.sm)
        }
        .background(DTColor.background)
        .onAppear { installEventMonitor() }
        .onDisappear { removeEventMonitor() }
    }

    private var searchField: some View {
        HStack(spacing: DTSpace.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DTColor.textSecondary)
            TextField("Search commands", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DTColor.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DTSpace.sm)
        .background(DTColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous)
                .strokeBorder(DTColor.border, lineWidth: 0.5)
        )
        .padding(.horizontal, DTSpace.md)
        .padding(.top, DTSpace.sm)
    }

    private func execute(_ command: CommandDescriptor) {
        command.action()
        onClose()
    }

    private func installEventMonitor() {
        selection = filteredCommands.first?.id
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            switch event.keyCode {
            case 53, 36, 76, 125, 126:
                handleKey(event)
                return nil
            default:
                return event
            }
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKey(_ event: NSEvent) {
        switch event.keyCode {
        case 53:
            onClose()
        case 36, 76:
            if let id = selection, let command = commands.first(where: { $0.id == id }) {
                execute(command)
            }
        case 125:
            moveSelection(by: 1)
        case 126:
            moveSelection(by: -1)
        default:
            break
        }
    }

    private func moveSelection(by delta: Int) {
        let items = filteredCommands
        guard !items.isEmpty else { return }
        let currentIndex: Int
        if let id = selection, let index = items.firstIndex(where: { $0.id == id }) {
            currentIndex = index
        } else {
            currentIndex = -1
        }
        let newIndex = (currentIndex + delta + items.count) % items.count
        selection = items[newIndex].id
    }
}

private struct CommandPaletteRow: View {
    let command: CommandDescriptor
    let isSelected: Bool
    let onExecute: () -> Void

    var body: some View {
        Button {
            onExecute()
        } label: {
            HStack(spacing: DTSpace.sm) {
                Image(systemName: command.iconName ?? "command")
                    .foregroundStyle(DTColor.accent)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    Text(command.title)
                        .font(DTTypography.body)
                        .lineLimit(1)
                    if let subtitle = command.subtitle {
                        Text(subtitle)
                            .font(DTTypography.caption)
                            .foregroundStyle(DTColor.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.vertical, DTSpace.xs)
            .padding(.horizontal, DTSpace.sm)
            .background(isSelected ? DTColor.accent.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
