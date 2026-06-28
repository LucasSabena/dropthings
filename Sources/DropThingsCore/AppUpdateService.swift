import Foundation
import Combine

public struct AppUpdateRelease: Equatable, Identifiable, Sendable {
    public var id: String { version }

    public let version: String
    public let releaseURL: URL
    public let downloadURL: URL?
    public let publishedAt: Date?
    public let changelog: String

    public init(
        version: String,
        releaseURL: URL,
        downloadURL: URL?,
        publishedAt: Date?,
        changelog: String
    ) {
        self.version = version
        self.releaseURL = releaseURL
        self.downloadURL = downloadURL
        self.publishedAt = publishedAt
        self.changelog = changelog
    }
}

public enum AppUpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate(checkedAt: Date)
    case updateAvailable(AppUpdateRelease, checkedAt: Date)
    case failed(message: String, checkedAt: Date?)

    public var isChecking: Bool {
        if case .checking = self { return true }
        return false
    }

    public var availableRelease: AppUpdateRelease? {
        if case .updateAvailable(let release, _) = self { return release }
        return nil
    }

    public var checkedAt: Date? {
        switch self {
        case .idle, .checking:
            return nil
        case .upToDate(let checkedAt):
            return checkedAt
        case .updateAvailable(_, let checkedAt):
            return checkedAt
        case .failed(_, let checkedAt):
            return checkedAt
        }
    }
}

public protocol AppUpdateClient: Sendable {
    func latestRelease() async throws -> AppUpdateRelease
}

public enum AppUpdateError: LocalizedError, Sendable {
    case invalidResponse(Int)
    case missingReleaseVersion
    case invalidReleaseURL

    public var errorDescription: String? {
        switch self {
        case .invalidResponse(let statusCode):
            return "Update server returned HTTP \(statusCode)."
        case .missingReleaseVersion:
            return "The latest release does not include a version tag."
        case .invalidReleaseURL:
            return "The latest release does not include a valid URL."
        }
    }
}

public struct GitHubReleasesUpdateClient: AppUpdateClient {
    private let owner: String
    private let repository: String
    private let session: URLSession

    public init(owner: String, repository: String, session: URLSession = .shared) {
        self.owner = owner
        self.repository = repository
        self.session = session
    }

    public func latestRelease() async throws -> AppUpdateRelease {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("DropThings update checker", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AppUpdateError.invalidResponse(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let release = try decoder.decode(GitHubReleaseResponse.self, from: data)
        guard !release.tagName.isEmpty else {
            throw AppUpdateError.missingReleaseVersion
        }
        guard let releaseURL = URL(string: release.htmlURL) else {
            throw AppUpdateError.invalidReleaseURL
        }

        let asset = release.assets.first { asset in
            let lowercasedName = asset.name.lowercased()
            return lowercasedName.hasSuffix(".dmg") || lowercasedName.hasSuffix(".zip")
        }

        return AppUpdateRelease(
            version: Self.displayVersion(from: release.tagName),
            releaseURL: releaseURL,
            downloadURL: asset.flatMap { URL(string: $0.browserDownloadURL) },
            publishedAt: release.publishedAt,
            changelog: release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    private static func displayVersion(from tag: String) -> String {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "v" || trimmed.first == "V" else { return trimmed }
        return String(trimmed.dropFirst())
    }
}

@MainActor
public final class AppUpdateService: ObservableObject {
    public static let defaultCheckInterval: TimeInterval = 60 * 60 * 24

    @Published public private(set) var state: AppUpdateState = .idle
    @Published public private(set) var automaticChecksEnabled: Bool
    @Published public private(set) var lastCheckedAt: Date?

    private let settings: SettingsStore
    private let client: AppUpdateClient
    private let currentVersionProvider: @MainActor () -> String
    private let now: () -> Date
    private let checkInterval: TimeInterval

    public init(
        settings: SettingsStore,
        client: AppUpdateClient,
        currentVersion: @escaping @MainActor () -> String,
        now: @escaping () -> Date = Date.init,
        checkInterval: TimeInterval = AppUpdateService.defaultCheckInterval
    ) {
        self.settings = settings
        self.client = client
        self.currentVersionProvider = currentVersion
        self.now = now
        self.checkInterval = checkInterval
        self.automaticChecksEnabled = settings.bool(Keys.automaticChecksEnabled, default: true)

        let storedLastCheck = settings.double(Keys.lastCheckedAt, default: 0)
        self.lastCheckedAt = storedLastCheck > 0 ? Date(timeIntervalSince1970: storedLastCheck) : nil
    }

    public func setAutomaticChecksEnabled(_ enabled: Bool) {
        automaticChecksEnabled = enabled
        settings.setBool(enabled, Keys.automaticChecksEnabled)
    }

    public func checkAutomaticallyIfNeeded() {
        guard automaticChecksEnabled, shouldCheckAutomatically else { return }
        checkNow()
    }

    public func checkNow() {
        guard !state.isChecking else { return }
        Task { await checkForUpdates() }
    }

    public func checkForUpdates() async {
        guard !state.isChecking else { return }
        state = .checking

        do {
            let release = try await client.latestRelease()
            let checkedAt = now()
            recordCheck(at: checkedAt)
            if AppVersion(release.version) > AppVersion(currentVersionProvider()) {
                state = .updateAvailable(release, checkedAt: checkedAt)
            } else {
                state = .upToDate(checkedAt: checkedAt)
            }
        } catch {
            state = .failed(message: error.localizedDescription, checkedAt: lastCheckedAt)
        }
    }

    private var shouldCheckAutomatically: Bool {
        guard let lastCheckedAt else { return true }
        return now().timeIntervalSince(lastCheckedAt) >= checkInterval
    }

    private func recordCheck(at date: Date) {
        lastCheckedAt = date
        settings.setDouble(date.timeIntervalSince1970, Keys.lastCheckedAt)
    }

    private enum Keys {
        static let automaticChecksEnabled = SettingsKey("core.updates.automaticChecksEnabled")
        static let lastCheckedAt = SettingsKey("core.updates.lastCheckedAt")
    }
}

private struct GitHubReleaseResponse: Decodable {
    let tagName: String
    let htmlURL: String
    let publishedAt: Date?
    let body: String?
    let assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case body
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
