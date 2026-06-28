import Foundation
import AppKit

/// Export and import the entire `app.dropthings` UserDefaults suite via the
/// system `defaults` command. The plist format is round-trippable and
/// matches what the OS itself produces when you run
/// `defaults read app.dropthings`.
@MainActor
final class SettingsImporter {
    let suiteName: String
    var onImport: (() -> Void)?

    init(suiteName: String) {
        self.suiteName = suiteName
    }

    func export(to url: URL) throws {
        try runDefaults(arguments: ["export", suiteName, url.path])
    }

    func `import`(from url: URL) throws {
        try runDefaults(arguments: ["import", suiteName, url.path])
        onImport?()
    }

    private func runDefaults(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = arguments
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "exit \(process.terminationStatus)"
            throw NSError(
                domain: "SettingsImporter",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }
}
