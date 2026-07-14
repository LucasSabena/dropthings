import Foundation
import DropThingsCore

public struct PaletteHistoryRecord: Codable, Equatable, Sendable {
    public let resultID: String
    public var useCount: Int
    public var lastUsedAt: Date
}

public final class PaletteHistoryStore: @unchecked Sendable {
    private struct Payload: Codable {
        let version: Int
        var records: [PaletteHistoryRecord]
    }

    public static let key = SettingsKey("modules.command-palette.history")
    private let settings: SettingsStore
    private let maximumRecords: Int
    private let now: @Sendable () -> Date
    private let lock = NSLock()

    public init(settings: SettingsStore, maximumRecords: Int = 200, now: @escaping @Sendable () -> Date = { Date() }) {
        self.settings = settings
        self.maximumRecords = maximumRecords
        self.now = now
    }

    public func recordSuccessfulAction(resultID: String) {
        lock.withLock {
            var records = loadUnlocked()
            let date = now()
            if let index = records.firstIndex(where: { $0.resultID == resultID }) {
                records[index].useCount = min(records[index].useCount + 1, 100)
                records[index].lastUsedAt = date
            } else {
                records.append(PaletteHistoryRecord(resultID: resultID, useCount: 1, lastUsedAt: date))
            }
            records.sort { $0.lastUsedAt > $1.lastUsedAt }
            saveUnlocked(Array(records.prefix(maximumRecords)))
        }
    }

    public func scores() -> [String: Double] {
        lock.withLock {
            let date = now()
            return Dictionary(uniqueKeysWithValues: loadUnlocked().map { record in
                let ageDays = max(0, date.timeIntervalSince(record.lastUsedAt) / 86_400)
                let recency = 100 * exp(-ageDays / 14)
                let frequency = min(log2(Double(record.useCount) + 1) * 24, 80)
                return (record.resultID, recency + frequency)
            })
        }
    }

    public func clear() {
        lock.withLock { settings.remove(Self.key) }
    }

    public func records() -> [PaletteHistoryRecord] {
        lock.withLock { loadUnlocked() }
    }

    private func loadUnlocked() -> [PaletteHistoryRecord] {
        guard let data = settings.data(Self.key),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.version == 1 else {
            if settings.data(Self.key) != nil { settings.remove(Self.key) }
            return []
        }
        return payload.records
    }

    private func saveUnlocked(_ records: [PaletteHistoryRecord]) {
        guard let data = try? JSONEncoder().encode(Payload(version: 1, records: records)) else { return }
        settings.setData(data, Self.key)
    }
}
