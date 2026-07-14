import AppKit
import DropThingsCore

/// Hooks for app lifecycle. `.accessory` activation policy hides the dock
/// icon; the app lives in the menu bar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in
            AppServices.shared.registry.bootEnabledModules()
#if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--profile-command-palette") {
                await AppServices.shared.showCommandPaletteForVisualTesting(runQuerySequence: true)
            } else if arguments.contains("--show-command-palette") {
                await AppServices.shared.showCommandPaletteForVisualTesting()
            }
            if let previewIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "--preview-module-menu-bar"),
               ProcessInfo.processInfo.arguments.indices.contains(previewIndex + 1) {
                let moduleID = ModuleID(ProcessInfo.processInfo.arguments[previewIndex + 1])
                try? await Task.sleep(for: .milliseconds(800))
                AppServices.shared.showMenuBarItemForVisualTesting(moduleID: moduleID)
            }
#endif
            if ProcessInfo.processInfo.arguments.contains("--show-settings") {
                AppServices.shared.settingsWindow.show()
            } else {
                AppServices.shared.presentControlCenterOnFirstLaunch()
            }
            AppServices.shared.updates.checkAutomaticallyIfNeeded()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            AppServices.shared.permissions.refresh()
            await AppServices.shared.registry.refreshPermissionsAndRetry()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Force UserDefaults to flush before the runloop tears down. Without
        // this, a setting changed a few seconds before quit can be lost if the
        // process is killed (Cmd+Q should normally flush, but `pkill` and
        // forced reloads do not).
        UserDefaults.standard.synchronize()

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
