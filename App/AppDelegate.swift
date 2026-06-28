import AppKit

/// Hooks for app lifecycle. `.accessory` activation policy hides the dock
/// icon; the app lives in the menu bar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in
            AppServices.shared.registry.bootEnabledModules()
            AppServices.shared.presentOnboardingIfNeeded()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            AppServices.shared.permissions.refresh()
            await AppServices.shared.registry.refreshPermissionsAndRetry()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Fire-and-forget shutdown. We cannot synchronously wait on a MainActor
        // task from the main thread without deadlocking the runloop.
        //
        // Real modules with event taps / menu bar observers must tear down
        // critical listeners synchronously inside their `stop()` before doing
        // any remaining async work, so the system is in a clean state even if
        // this task does not finish before the process exits.
        Task { @MainActor in
            await AppServices.shared.registry.stopAll()
        }
    }
}
