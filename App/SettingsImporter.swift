import Foundation
import AppKit

/// Export and import the entire app preferences domain as a round-trippable
/// plist. Importing in-process avoids stale `UserDefaults` caches caused by
/// invoking the `defaults` command behind the running app's back.
@MainActor
final class SettingsImporter {
    let suiteName: String
    var onImport: (() -> Void)?

    init(suiteName: String) {
        self.suiteName = suiteName
    }

    func export(to url: URL) throws {
        let domain = UserDefaults.standard.persistentDomain(forName: suiteName) ?? [:]
        let data = try PropertyListSerialization.data(
            fromPropertyList: domain,
            format: .xml,
            options: 0
        )
        try data.write(to: url, options: .atomic)
    }

    func `import`(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let domain = plist as? [String: Any] else {
            throw NSError(
                domain: "SettingsImporter",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The selected plist is not a preferences dictionary."]
            )
        }
        UserDefaults.standard.setPersistentDomain(domain, forName: suiteName)
        onImport?()
    }
}
