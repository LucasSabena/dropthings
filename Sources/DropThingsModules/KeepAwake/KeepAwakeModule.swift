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
public final class KeepAwakeModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.keepAwake
    public let name = "Keep Awake"
    public let summary = "Prevent your Mac from sleeping while this is on."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: KeepAwakeSettings
    @Published public private(set) var isAssertionActive: Bool = false
    @Published public private(set) var activeAssertionIDs: [UInt32] = []
    @Published public private(set) var lastError: String?

    private let settingsStore: SettingsStore
    private let assertion = KeepAwakeAssertion()
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "keep-awake")

    public init(settings: SettingsStore) {
        self.settingsStore = settings
        self.settings = settings.loadKeepAwakeSettings()
    }

    public func start() async throws {
        applyState(settings.enabled)
        if case .degraded = state {
            logger.warning("Keep Awake started degraded")
        } else {
            state = .running
        }
        logger.info("Keep Awake started")
    }

    public func stop() async {
        assertion.release()
        syncAssertionState()
        if settings.enabled {
            settings.enabled = false
            persistSettings()
        }
        state = .off
        logger.info("Keep Awake stopped")
    }

    /// Toggle the awake state. When `true`, holds a system sleep
    /// assertion until `false` (or the module is stopped). The setting
    /// persists across launches.
    public func setKeepingAwake(_ enabled: Bool) {
        var new = settings
        new.enabled = enabled
        applySettings(new)
    }

    public var keepAwakeSettings: KeepAwakeSettings { settings }

    private func applySettings(_ new: KeepAwakeSettings) {
        settings = new
        persistSettings()
        if state == .running {
            applyState(new.enabled)
        }
    }

    private func persistSettings() {
        settingsStore.saveKeepAwakeSettings(settings)
    }

    private func applyState(_ enabled: Bool) {
        do {
            if enabled {
                try assertion.acquireKeepAwakeAssertions()
                syncAssertionState()
                lastError = nil
                logger.info("Assertions acquired (ids=\(self.assertion.currentAssertionIDs.map(String.init).joined(separator: ",")))")
            } else {
                assertion.release()
                syncAssertionState()
                lastError = nil
                logger.info("Assertion released")
            }
        } catch let error as KeepAwakeAssertion.FailureReason {
            logger.warning("Could not change assertion state: \(error)")
            syncAssertionState()
            lastError = "Could not keep Mac awake: \(error)"
            state = .degraded(reason: "Could not keep Mac awake: \(error). macOS may have refused the power assertion.")
        } catch {
            logger.warning("Could not change assertion state: \(error)")
            syncAssertionState()
            lastError = "Could not keep Mac awake: \(error)"
            state = .degraded(reason: "Could not keep Mac awake: \(error)")
        }
    }

    private func syncAssertionState() {
        isAssertionActive = assertion.isActive
        activeAssertionIDs = assertion.currentAssertionIDs
    }

    public func makeSettingsView() -> AnyView {
        AnyView(KeepAwakeSettingsView(module: self))
    }
}
