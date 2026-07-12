import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Prevents the Mac from idling to sleep while the module's single
/// toggle is on. The system behaves as if you were actively using it.
/// When off, macOS uses the user's normal power settings. The module
/// holds a `PreventUserIdleSystemSleep` assertion via `IOPMAssertion`.
public final class KeepAwakeModule: DropThingsModule {
    public let id = ModuleID.keepAwake
    public let name = "Keep Awake"
    public let summary = "Prevent your Mac from sleeping while this is on."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: KeepAwakeSettings
    @Published public private(set) var isAssertionActive: Bool = false
    @Published public private(set) var activeAssertionIDs: [UInt32] = []
    @Published public private(set) var lastError: String?
    @Published public private(set) var remainingSeconds: TimeInterval?

    private let settingsStore: SettingsStore
    private let assertion: KeepAwakeAssertionProtocol
    private var assertionHealth = RecoverableFailureHealth()
    private var expirationTask: Task<Void, Never>?
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "keep-awake")

    public init(settings: SettingsStore) {
        self.settingsStore = settings
        self.settings = settings.loadKeepAwakeSettings()
        self.assertion = KeepAwakeAssertion()
    }

    internal init(settings: SettingsStore, assertion: KeepAwakeAssertionProtocol) {
        self.settingsStore = settings
        self.settings = settings.loadKeepAwakeSettings()
        self.assertion = assertion
    }

    public func start() async throws {
        if let activeUntil = settings.activeUntil, activeUntil <= Date() {
            var expired = settings
            expired.enabled = false
            expired.activeUntil = nil
            settings = expired
            persistSettings()
        }
        applyState(settings.enabled)
        scheduleExpirationIfNeeded()
        if case .degraded = state {
            logger.warning("Keep Awake started degraded")
        } else {
            state = .running
        }
        logger.info("Keep Awake started")
    }

    public func stop() async {
        // Release the assertion but keep the user's preferred on/off value.
        // Re-enabling the module or relaunching restores that preference.
        assertion.release()
        expirationTask?.cancel()
        expirationTask = nil
        remainingSeconds = nil
        syncAssertionState()
        state = .off
        logger.info("Keep Awake stopped")
    }

    /// One-tap entry point from the menu bar.
    public var primaryAction: ModulePrimaryAction? {
        ModulePrimaryAction(
            title: isAssertionActive ? "Disable Keep Awake" : "Enable Keep Awake",
            iconName: iconName,
            action: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.toggleKeepingAwake()
                }
            }
        )
    }

    public var commands: [CommandDescriptor] {
        [
            CommandDescriptor(
                id: "keep-awake.toggle",
                title: isAssertionActive ? "Disable Keep Awake" : "Enable Keep Awake",
                subtitle: name,
                iconName: iconName,
                action: { [weak self] in
                    Task { @MainActor [weak self] in self?.toggleKeepingAwake() }
                }
            )
        ]
    }

    /// Toggle the awake state. When `true`, holds a system sleep
    /// assertion until `false` (or the module is stopped). The setting
    /// persists across launches.
    public func setKeepingAwake(_ enabled: Bool) {
        var new = settings
        new.enabled = enabled
        new.activeUntil = enabled ? expirationDate(for: new.durationMinutes) : nil
        applySettings(new)
    }

    public func setKeepDisplayAwake(_ enabled: Bool) {
        var new = settings
        new.keepDisplayAwake = enabled
        applySettings(new)
    }

    public func setDurationMinutes(_ minutes: Int?) {
        var new = settings
        new.durationMinutes = minutes
        if new.enabled {
            new.activeUntil = expirationDate(for: minutes)
        }
        applySettings(new)
    }

    /// Flip the current keep-awake state without knowing the current value.
    public func toggleKeepingAwake() {
        setKeepingAwake(!settings.enabled)
    }

    public var keepAwakeSettings: KeepAwakeSettings { settings }

    private func applySettings(_ new: KeepAwakeSettings) {
        settings = new
        persistSettings()
        if state.isStarted {
            applyState(new.enabled)
        }
        scheduleExpirationIfNeeded()
    }

    private func persistSettings() {
        settingsStore.saveKeepAwakeSettings(settings)
    }

    private func applyState(_ enabled: Bool) {
        do {
            if enabled {
                try assertion.acquireKeepAwakeAssertions(keepDisplayAwake: settings.keepDisplayAwake)
                syncAssertionState()
                lastError = nil
                state = assertionHealth.recovered(current: state)
                logger.info("Assertions acquired (ids=\(self.assertion.currentAssertionIDs.map(String.init).joined(separator: ",")))")
            } else {
                assertion.release()
                syncAssertionState()
                lastError = nil
                state = assertionHealth.recovered(current: state)
                logger.info("Assertion released")
            }
        } catch let error as KeepAwakeAssertion.FailureReason {
            logger.warning("Could not change assertion state: \(error)")
            syncAssertionState()
            lastError = "Could not keep Mac awake: \(error)"
            state = assertionHealth.failed(
                reason: "Could not keep Mac awake: \(error). macOS may have refused the power assertion."
            )
        } catch {
            logger.warning("Could not change assertion state: \(error)")
            syncAssertionState()
            lastError = "Could not keep Mac awake: \(error)"
            state = assertionHealth.failed(reason: "Could not keep Mac awake: \(error)")
        }
    }

    private func syncAssertionState() {
        isAssertionActive = assertion.isActive
        activeAssertionIDs = assertion.currentAssertionIDs
    }

    private func expirationDate(for minutes: Int?) -> Date? {
        minutes.map { Date().addingTimeInterval(Double($0) * 60) }
    }

    private func scheduleExpirationIfNeeded() {
        expirationTask?.cancel()
        expirationTask = nil
        guard settings.enabled, let activeUntil = settings.activeUntil else {
            remainingSeconds = nil
            return
        }
        remainingSeconds = max(0, activeUntil.timeIntervalSinceNow)
        expirationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, let end = self.settings.activeUntil else { return }
                let remaining = end.timeIntervalSinceNow
                self.remainingSeconds = max(0, remaining)
                if remaining <= 0 {
                    self.setKeepingAwake(false)
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    public func makeSettingsView() -> AnyView {
        AnyView(KeepAwakeSettingsView(module: self))
    }
}
