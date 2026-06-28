import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform
import os

/// Prevents the Mac from going to sleep while the module is enabled. The
/// user chooses between "system sleep" and "display sleep" (the latter is
/// less invasive — display can still turn off, only the system stays
/// awake). Powered by `IOPMAssertionCreateWithName` through the
/// `KeepAwakeAssertion` Platform adapter.
public final class KeepAwakeModule: DropThingsModule, ObservableObject {
    public let id = ModuleID.keepAwake
    public let name = "Keep Awake"
    public let summary = "Stop your Mac from sleeping while this is on."
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var isKeepingAwake: Bool = false
    @Published public private(set) var settings: KeepAwakeSettings

    private let settingsStore: SettingsStore
    private let assertion = KeepAwakeAssertion()
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "keep-awake")

    public init(settings: SettingsStore) {
        self.settingsStore = settings
        self.settings = settings.loadKeepAwakeSettings()
    }

    public func start() async throws {
        if settings.restoreOnLaunch {
            applyState(true)
        }
        state = .running
        logger.info("Keep Awake started")
    }

    public func stop() async {
        applyState(false)
        state = .off
        logger.info("Keep Awake stopped")
    }

    public func setKeepingAwake(_ enabled: Bool) {
        applyState(enabled)
    }

    public func setPreferredReason(_ reason: KeepAwakeAssertion.Reason) {
        var new = settings
        new.preferredReason = reason
        applySettings(new)
        if isKeepingAwake {
            applyState(true)
        }
    }

    public func setRestoreOnLaunch(_ restore: Bool) {
        var new = settings
        new.restoreOnLaunch = restore
        applySettings(new)
    }

    public var keepAwakeSettings: KeepAwakeSettings { settings }

    private func applyState(_ enabled: Bool) {
        do {
            if enabled {
                try assertion.acquire(reason: settings.preferredReason)
                isKeepingAwake = true
                logger.info("Assertion acquired (\(self.settings.preferredReason.rawValue))")
            } else {
                assertion.release()
                isKeepingAwake = false
                logger.info("Assertion released")
            }
        } catch let error as KeepAwakeAssertion.FailureReason {
            logger.warning("Could not change assertion state: \(error)")
            isKeepingAwake = false
            state = .degraded(reason: "Could not keep Mac awake: \(error)")
        } catch {
            logger.warning("Could not change assertion state: \(error)")
            isKeepingAwake = false
            state = .degraded(reason: "Could not keep Mac awake: \(error)")
        }
    }

    private func applySettings(_ new: KeepAwakeSettings) {
        settings = new
        settingsStore.saveKeepAwakeSettings(new)
    }

    public func makeSettingsView() -> AnyView {
        AnyView(KeepAwakeSettingsView(module: self))
    }
}

