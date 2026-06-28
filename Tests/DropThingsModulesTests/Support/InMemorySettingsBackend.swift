import Foundation
@testable import DropThingsCore

/// In-memory backend for settings tests. Behaves like `UserDefaults` minus
/// the persistence side effects. Duplicated in `DropThingsCoreTests` because
/// SPM does not let two test targets share source files cleanly.
final class InMemorySettingsBackend: SettingsStoreBackend, @unchecked Sendable {
    private var storage: [String: Any] = [:]
    private let lock = NSLock()

    func integer(forKey key: String) -> Int? {
        lock.withLock { storage[key] as? Int }
    }

    func setInteger(_ value: Int, forKey key: String) {
        lock.withLock { storage[key] = value }
    }

    func double(forKey key: String) -> Double? {
        lock.withLock { storage[key] as? Double }
    }

    func setDouble(_ value: Double, forKey key: String) {
        lock.withLock { storage[key] = value }
    }

    func bool(forKey key: String) -> Bool? {
        lock.withLock { storage[key] as? Bool }
    }

    func setBool(_ value: Bool, forKey key: String) {
        lock.withLock { storage[key] = value }
    }

    func string(forKey key: String) -> String? {
        lock.withLock { storage[key] as? String }
    }

    func setString(_ value: String, forKey key: String) {
        lock.withLock { storage[key] = value }
    }

    func data(forKey key: String) -> Data? {
        lock.withLock { storage[key] as? Data }
    }

    func setData(_ value: Data, forKey key: String) {
        lock.withLock { storage[key] = value }
    }

    func removeValue(forKey key: String) {
        lock.withLock { _ = storage.removeValue(forKey: key) }
    }

    func allKeys() -> Set<String> {
        lock.withLock { Set(storage.keys) }
    }
}

