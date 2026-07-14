import AppKit
import Combine
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem

/// App-shell owner for independent module status items. Modules never touch
/// NSStatusItem or NSPopover directly; they declare a presentation and Core's
/// preferences decide whether it exists.
@MainActor
final class ModuleMenuBarController {
    private let registry: ModuleRegistry
    private let preferences: ModuleMenuBarPreferences
    private let openSettings: (ModuleID) -> Void
    private var items: [ModuleID: ModuleStatusItem] = [:]
    private var cancellables: Set<AnyCancellable> = []
#if DEBUG
    private var visualTestingWindow: NSWindowController?
#endif

    init(
        registry: ModuleRegistry,
        preferences: ModuleMenuBarPreferences,
        openSettings: @escaping (ModuleID) -> Void
    ) {
        self.registry = registry
        self.preferences = preferences
        self.openSettings = openSettings

        registry.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                DispatchQueue.main.async { self?.synchronize() }
            }
            .store(in: &cancellables)
        preferences.$explicitVisibility
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.synchronize() }
            }
            .store(in: &cancellables)

        synchronize()
    }

    func synchronize() {
        let eligible = registry.modules.values.filter { module in
            guard let presentation = module.menuBarPresentation else { return false }
            return registry.isEnabled(module.id)
                && preferences.isVisible(
                    for: module.id,
                    default: presentation.isVisibleByDefault
                )
        }
        let eligibleIDs = Set(eligible.map(\.id))

        for id in items.keys where !eligibleIDs.contains(id) {
            items[id]?.close()
            items[id] = nil
        }

        for module in eligible where items[module.id] == nil {
            guard let presentation = module.menuBarPresentation else { continue }
            items[module.id] = ModuleStatusItem(
                moduleID: module.id,
                presentation: presentation,
                closeOthers: { [weak self] id in self?.closeAll(except: id) },
                openSettings: { [weak self] id in self?.openSettings(id) }
            )
        }
    }

#if DEBUG
    /// Deterministic visual-QA hook. It is compiled out of Release and renders
    /// the same root view as the popover in a capturable panel.
    func showForVisualTesting(moduleID: ModuleID) {
        guard let module = registry.modules[moduleID],
              let presentation = module.menuBarPresentation else { return }
        let root = ModuleMenuBarPopoverView(
            moduleName: presentation.accessibilityLabel,
            content: presentation.makeContentView(),
            contentSize: presentation.preferredContentSize,
            openSettings: { [weak self] in self?.openSettings(moduleID) }
        )
        let controller = NSHostingController(rootView: root)
        let window = NSPanel(contentViewController: controller)
        window.title = "Audio Control"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(presentation.preferredContentSize)
        window.center()
        window.level = .floating
        visualTestingWindow = NSWindowController(window: window)
        visualTestingWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
#endif

    private func closeAll(except moduleID: ModuleID) {
        for (id, item) in items where id != moduleID {
            item.close()
        }
    }
}

@MainActor
private final class ModuleStatusItem: NSObject {
    private let moduleID: ModuleID
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let closeOthers: (ModuleID) -> Void

    init(
        moduleID: ModuleID,
        presentation: ModuleMenuBarPresentation,
        closeOthers: @escaping (ModuleID) -> Void,
        openSettings: @escaping (ModuleID) -> Void
    ) {
        self.moduleID = moduleID
        self.closeOthers = closeOthers
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureStatusButton(with: presentation)
        configurePopover(with: presentation, openSettings: openSettings)
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func close() {
        popover.performClose(nil)
    }

    func show() {
        guard let button = statusItem.button else { return }
        closeOthers(moduleID)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            close()
            return
        }
        show()
    }

    private func configureStatusButton(with presentation: ModuleMenuBarPresentation) {
        guard let button = statusItem.button else { return }
        let image = NSImage(
            systemSymbolName: presentation.iconName,
            accessibilityDescription: presentation.accessibilityLabel
        )
        image?.isTemplate = true
        button.image = image
        button.toolTip = presentation.accessibilityLabel
        button.setAccessibilityLabel(presentation.accessibilityLabel)
        button.target = self
        button.action = #selector(togglePopover(_:))
        statusItem.autosaveName = "app.dropthings.module.\(moduleID.rawValue)"
    }

    private func configurePopover(
        with presentation: ModuleMenuBarPresentation,
        openSettings: @escaping (ModuleID) -> Void
    ) {
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.contentSize = presentation.preferredContentSize
        popover.contentViewController = NSHostingController(
            rootView: ModuleMenuBarPopoverView(
                moduleName: presentation.accessibilityLabel,
                content: presentation.makeContentView(),
                contentSize: presentation.preferredContentSize,
                openSettings: { [weak self] in
                    guard let self else { return }
                    self.close()
                    openSettings(self.moduleID)
                }
            )
        )
    }
}

private struct ModuleMenuBarPopoverView: View {
    let moduleName: String
    let content: AnyView
    let contentSize: CGSize
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(
                    width: contentSize.width,
                    height: contentSize.height - DTSize.moduleMenuBarFooterHeight
                )

            Divider()

            HStack(spacing: DTSpace.sm) {
                Text(moduleName)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                Spacer()
                Button(action: openSettings) {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                .keyboardShortcut(",")
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut("q")
            }
            .padding(.horizontal, DTSpace.md)
            .frame(height: DTSize.moduleMenuBarFooterHeight)
            .background(.bar)
        }
        .frame(width: contentSize.width, height: contentSize.height)
    }
}
