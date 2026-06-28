import AppKit
import Sparkle
import Combine

/// Thin wrapper around Sparkle 2 that exposes the update state to the
/// SwiftUI settings UI. Sparkle owns the actual check/download/install
/// flow; this controller only bridges its delegate callbacks and
/// triggers checks.
@MainActor
final class SparkleUpdaterController: NSObject, ObservableObject {
    @Published private(set) var state: SparkleUpdateState = .idle
    @Published var automaticChecksEnabled: Bool {
        didSet {
            updater.automaticallyChecksForUpdates = automaticChecksEnabled
            UserDefaults.standard.set(automaticChecksEnabled, forKey: Self.automaticChecksKey)
        }
    }

    private let updater: SPUUpdater
    private var cancellables: Set<AnyCancellable> = []

    private static let automaticChecksKey = "SUEnableAutomaticChecks"

    override init() {
        let userDriver = SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil)
        let updater = SPUUpdater(
            hostBundle: Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: userDriver,
            delegate: nil
        )
        self.updater = updater
        self.automaticChecksEnabled = UserDefaults.standard.object(forKey: Self.automaticChecksKey) as? Bool ?? true
        super.init()
        updater.automaticallyChecksForUpdates = automaticChecksEnabled
        updater.updateCheckInterval = 60 * 60 * 24
    }

    /// Open the Sparkle "Check for Updates" window. Sparkle handles
    /// detecting, downloading, and prompting the user to install/restart.
    func checkNow() {
        state = .checking
        updater.checkForUpdates()
    }

    func checkAutomaticallyIfNeeded() {
        // Sparkle already handles automatic scheduling via SUEnableAutomaticChecks.
    }
}

enum SparkleUpdateState: Equatable {
    case idle
    case checking
    case updateAvailable(version: String, changelog: String?)
    case downloading(progress: Double)
    case installing
    case failed(message: String)
    case upToDate
}
