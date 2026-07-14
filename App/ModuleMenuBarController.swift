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
            let enabled = registry.isEnabled(module.id)
            let visible = preferences.isVisible(
                    for: module.id,
                    default: presentation.isVisibleByDefault
                )
            let pinnedLifecycleToggle = presentation.togglesModuleLifecycle
                && preferences.hasExplicitVisibility(for: module.id)
            return visible && (enabled || pinnedLifecycleToggle)
        }
        let eligibleIDs = Set(eligible.map(\.id))

        for id in items.keys where !eligibleIDs.contains(id) {
            items[id]?.close()
            items[id] = nil
        }

        for module in eligible where items[module.id] == nil {
            guard let presentation = module.menuBarPresentation else { continue }
            items[module.id] = ModuleStatusItem(
                module: module,
                presentation: presentation,
                closeOthers: { [weak self] id in self?.closeAll(except: id) },
                openSettings: { [weak self] id in self?.openSettings(id) }
                , isEnabled: { [weak self] id in self?.registry.isEnabled(id) ?? false }
                , setEnabled: { [weak self] enabled, id in self?.registry.setEnabled(enabled, for: id) }
            )
        }
    }

#if DEBUG
    /// Deterministic visual-QA hook. It is compiled out of Release and renders
    /// the same root view as the popover in a capturable panel.
    func showForVisualTesting(moduleID: ModuleID) {
        guard let module = registry.modules[moduleID],
              let presentation = module.menuBarPresentation,
              let content = presentation.makeContentView() else { return }
        let root = ModuleMenuBarPopoverView(
            moduleName: presentation.accessibilityLabel,
            content: content,
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
    private let module: any DropThingsModule
    private var moduleID: ModuleID { module.id }
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let closeOthers: (ModuleID) -> Void
    private let openSettings: (ModuleID) -> Void
    private let isEnabled: (ModuleID) -> Bool
    private let setEnabled: (Bool, ModuleID) -> Void
    private let togglesModuleLifecycle: Bool
    private var cancellable: AnyCancellable?

    init(
        module: any DropThingsModule,
        presentation: ModuleMenuBarPresentation,
        closeOthers: @escaping (ModuleID) -> Void,
        openSettings: @escaping (ModuleID) -> Void,
        isEnabled: @escaping (ModuleID) -> Bool,
        setEnabled: @escaping (Bool, ModuleID) -> Void
    ) {
        self.module = module
        self.closeOthers = closeOthers
        self.openSettings = openSettings
        self.isEnabled = isEnabled
        self.setEnabled = setEnabled
        self.togglesModuleLifecycle = presentation.togglesModuleLifecycle
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureStatusButton(with: presentation)
        configurePopover(with: presentation, openSettings: openSettings)
        cancellable = module.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshStatusIcon() }
        }
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func close() {
        popover.performClose(nil)
    }

    func show() {
        guard let button = statusItem.button else { return }
        guard popover.contentViewController != nil else {
            if togglesModuleLifecycle {
                setEnabled(!isEnabled(moduleID), moduleID)
                return
            }
            if let action = module.primaryAction { action.action() }
            else { openSettings(moduleID) }
            return
        }
        closeOthers(moduleID)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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
            systemSymbolName: module.menuBarIconName,
            accessibilityDescription: module.menuBarAccessibilityLabel
        )
        image?.isTemplate = true
        button.image = image
        button.toolTip = module.menuBarAccessibilityLabel
        button.setAccessibilityLabel(module.menuBarAccessibilityLabel)
        button.target = self
        button.action = #selector(togglePopover(_:))
        statusItem.autosaveName = "app.dropthings.module.\(moduleID.rawValue)"
    }

    private func refreshStatusIcon() {
        let label = module.menuBarAccessibilityLabel
        let image = NSImage(systemSymbolName: module.menuBarIconName, accessibilityDescription: label)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = label
        statusItem.button?.setAccessibilityLabel(label)
    }

    private func configurePopover(
        with presentation: ModuleMenuBarPresentation,
        openSettings: @escaping (ModuleID) -> Void
    ) {
        guard let content = presentation.makeContentView() else { return }
        // A module popup is temporary control surface. Once the user returns
        // to another app, dismiss it instead of leaving controls over that app.
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.contentSize = presentation.preferredContentSize
        popover.contentViewController = NSHostingController(
            rootView: ModuleMenuBarPopoverView(
                moduleName: presentation.accessibilityLabel,
                content: content,
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
