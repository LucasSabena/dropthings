import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

/// Temporarily suppresses physical keyboard input for cleaning. Unlocking is
/// intentionally mouse-only from the persistent menu-bar icon.
@MainActor
public final class KeyboardLockModule: DropThingsModule {
    public let id = ModuleID.keyboardLock
    public let name = "Keyboard Lock"
    public let summary = "Temporarily disable typing so you can clean your keyboard."
    public let requiredPermissions: [SystemPermission] = [.accessibility]

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var isKeyboardLocked = false
    @Published public private(set) var lastError: String?

    private let permissions: PermissionCenter
    private let tap: any KeyboardEventTapping

    public convenience init(permissions: PermissionCenter) {
        self.init(permissions: permissions, tap: KeyboardEventTap())
    }

    init(permissions: PermissionCenter, tap: any KeyboardEventTapping) {
        self.permissions = permissions
        self.tap = tap
    }

    public func start() async throws {
        guard permissions.state(for: .accessibility) == .granted else {
            state = .needsPermission(missing: permissions.missing(from: requiredPermissions))
            return
        }
        guard !state.isActive else { return }
        tap.stop()
        isKeyboardLocked = false
        lastError = nil
        state = .running
    }

    public func stop() async {
        tap.stop()
        isKeyboardLocked = false
        lastError = nil
        state = .off
    }

    public var primaryAction: ModulePrimaryAction? {
        ModulePrimaryAction(
            title: isKeyboardLocked ? "Unlock Keyboard" : "Lock Keyboard",
            iconName: menuBarIconName,
            action: { [weak self] in Task { @MainActor in self?.toggleLock() } }
        )
    }

    public var commands: [CommandDescriptor] {
        [CommandDescriptor(
            id: "keyboard-lock.toggle",
            title: isKeyboardLocked ? "Unlock Keyboard" : "Lock Keyboard",
            subtitle: name,
            iconName: menuBarIconName,
            action: { [weak self] in Task { @MainActor in self?.toggleLock() } }
        )]
    }

    public var menuBarPresentation: ModuleMenuBarPresentation? {
        ModuleMenuBarPresentation(
            iconName: menuBarIconName,
            accessibilityLabel: menuBarAccessibilityLabel,
            preferredContentSize: CGSize(width: 320, height: 176),
            isVisibleByDefault: true,
            allowsVisibilityCustomization: false
        ) { [weak self] in
            guard let self else { return AnyView(EmptyView()) }
            return AnyView(KeyboardLockMenuBarView(module: self))
        }
    }

    public var menuBarIconName: String {
        isKeyboardLocked ? "keyboard.chevron.compact.down" : "keyboard"
    }

    public var menuBarAccessibilityLabel: String {
        isKeyboardLocked ? "Keyboard Lock: keyboard disabled. Click to unlock." : "Keyboard Lock: keyboard available."
    }

    public func toggleLock() {
        guard state.isStarted else { return }
        if isKeyboardLocked {
            unlockKeyboard()
        } else {
            lockKeyboard()
        }
    }

    private func lockKeyboard() {
        guard permissions.state(for: .accessibility) == .granted else {
            state = .needsPermission(missing: [.accessibility])
            return
        }
        tap.setLocked(true)
        do {
            try tap.start()
            isKeyboardLocked = true
            lastError = nil
            state = .running
        } catch {
            tap.stop()
            isKeyboardLocked = false
            lastError = error.localizedDescription
            state = .failed(
                reason: "Keyboard Lock could not block keys: \(error.localizedDescription)",
                recovery: "Confirm Accessibility access, then try Lock Keyboard again."
            )
        }
    }

    private func unlockKeyboard() {
        tap.stop()
        isKeyboardLocked = false
        lastError = nil
        state = .running
    }

    public func makeSettingsView() -> AnyView {
        AnyView(KeyboardLockSettingsView(module: self))
    }
}
