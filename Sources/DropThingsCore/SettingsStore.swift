import Foundation
import Combine

/// Typed key used by `SettingsStore`. Wraps `String` so we can grep for typos
/// and force migrations to enumerate keys explicitly.
public struct SettingsKey: Hashable, RawRepresentable, ExpressibleByStringLiteral, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.init(rawValue: value) }
}

/// One step in a settings migration. Migrations run on every read until the
/// stored schema version matches the current version.
public struct SettingsMigration: Sendable {
    public let fromVersion: Int
    public let run: @Sendable (SettingsStoreBackend) throws -> Void

    public init(fromVersion: Int, run: @escaping @Sendable (SettingsStoreBackend) throws -> Void) {
        self.fromVersion = fromVersion
        self.run = run
    }
}

/// Storage abstraction so tests can use an in-memory backend. The production
/// backend is `UserDefaults`.
public protocol SettingsStoreBackend: AnyObject, Sendable {
    func integer(forKey key: String) -> Int?
    func setInteger(_ value: Int, forKey key: String)
    func double(forKey key: String) -> Double?
    func setDouble(_ value: Double, forKey key: String)
    func bool(forKey key: String) -> Bool?
    func setBool(_ value: Bool, forKey key: String)
    func string(forKey key: String) -> String?
    func setString(_ value: String, forKey key: String)
    func data(forKey key: String) -> Data?
    func setData(_ value: Data, forKey key: String)
    func removeValue(forKey key: String)
    func allKeys() -> Set<String>
}

extension SettingsStoreBackend {
    /// Convenience for "set or clear". Use when `nil` is a valid stored value.
    public func setInteger(_ value: Int?, forKey key: String) {
        if let value { setInteger(value, forKey: key) } else { removeValue(forKey: key) }
    }

    public func setDouble(_ value: Double?, forKey key: String) {
        if let value { setDouble(value, forKey: key) } else { removeValue(forKey: key) }
    }

    public func setBool(_ value: Bool?, forKey key: String) {
        if let value { setBool(value, forKey: key) } else { removeValue(forKey: key) }
    }

    public func setString(_ value: String?, forKey key: String) {
        if let value { setString(value, forKey: key) } else { removeValue(forKey: key) }
    }

    public func setData(_ value: Data?, forKey key: String) {
        if let value { setData(value, forKey: key) } else { removeValue(forKey: key) }
    }
}

/// Typed wrapper around a `SettingsStoreBackend`. Keeps keys off the call sites
/// and runs migrations on first access.
public final class SettingsStore: @unchecked Sendable {
    public static let schemaVersionKey = SettingsKey("core.settings.schemaVersion")

    private let backend: SettingsStoreBackend
    private let migrations: [SettingsMigration]
    private let lock = NSLock()

    public init(backend: SettingsStoreBackend, migrations: [SettingsMigration] = []) {
        self.backend = backend
        self.migrations = migrations.sorted { $0.fromVersion < $1.fromVersion }
    }

    /// `UserDefaults`-backed store. The suite name should match the app's
    /// bundle identifier.
    public static func userDefaults(suiteName: String, migrations: [SettingsMigration] = []) -> SettingsStore {
        let backend = UserDefaultsBackend(suiteName: suiteName)
        return SettingsStore(backend: backend, migrations: migrations)
    }

    /// Run any pending migrations. Safe to call multiple times. The
    /// schema version only advances when every migration from the stored
    /// version up to `currentSchemaVersion` completes without throwing —
    /// otherwise we leave the store at the last successfully applied
    /// version so the next launch retries the failed step instead of
    /// silently skipping it.
    public func migrateIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        let stored = backend.integer(forKey: Self.schemaVersionKey.rawValue) ?? 0
        guard stored < Self.currentSchemaVersion else { return }
        var applied = stored
        for migration in migrations where migration.fromVersion >= applied {
            do {
                try migration.run(backend)
                applied = migration.fromVersion
                backend.setInteger(applied, forKey: Self.schemaVersionKey.rawValue)
            } catch {
                ModuleLogger(subsystem: "app.dropthings", category: "settings")
                    .error("Migration from v\(migration.fromVersion) failed: \(error). Schema stays at v\(applied); next launch will retry.")
                return
            }
        }
        backend.setInteger(Self.currentSchemaVersion, forKey: Self.schemaVersionKey.rawValue)
    }

    /// Read an integer with a default. Returns `default` when the key has no value.
    public func integer(_ key: SettingsKey, default defaultValue: Int) -> Int {
        read { $0.integer(forKey: key.rawValue) } ?? defaultValue
    }

    public func setInteger(_ value: Int, _ key: SettingsKey) {
        write { $0.setInteger(value, forKey: key.rawValue) }
    }

    public func double(_ key: SettingsKey, default defaultValue: Double) -> Double {
        read { $0.double(forKey: key.rawValue) } ?? defaultValue
    }

    public func setDouble(_ value: Double, _ key: SettingsKey) {
        write { $0.setDouble(value, forKey: key.rawValue) }
    }

    public func bool(_ key: SettingsKey, default defaultValue: Bool) -> Bool {
        read { $0.bool(forKey: key.rawValue) } ?? defaultValue
    }

    public func setBool(_ value: Bool, _ key: SettingsKey) {
        write { $0.setBool(value, forKey: key.rawValue) }
    }

    public func string(_ key: SettingsKey) -> String? {
        read { $0.string(forKey: key.rawValue) }
    }

    public func setString(_ value: String, _ key: SettingsKey) {
        write { $0.setString(value, forKey: key.rawValue) }
    }

    public func data(_ key: SettingsKey) -> Data? {
        read { $0.data(forKey: key.rawValue) }
    }

    public func setData(_ value: Data, _ key: SettingsKey) {
        write { $0.setData(value, forKey: key.rawValue) }
    }

    public func remove(_ key: SettingsKey) {
        write { $0.removeValue(forKey: key.rawValue) }
    }

    /// Bump this when you add a migration. The store replays every
    /// migration with `fromVersion >= stored` until the version matches.
    /// `let` because a runtime bump would race with migrations that read
    /// it mid-loop; a new schema ships as a code change, not at runtime.
    public static let currentSchemaVersion: Int = 1

    private func read<T>(_ block: (SettingsStoreBackend) -> T?) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return block(backend)
    }

    private func write(_ block: (SettingsStoreBackend) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        block(backend)
    }
}

/// Production `SettingsStoreBackend` backed by `UserDefaults`.
final class UserDefaultsBackend: SettingsStoreBackend, @unchecked Sendable {
    private let defaults: UserDefaults

    init(suiteName: String) {
        if let suite = UserDefaults(suiteName: suiteName) {
            self.defaults = suite
        } else {
            self.defaults = .standard
        }
    }

    func integer(forKey key: String) -> Int? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.integer(forKey: key)
    }

    func setInteger(_ value: Int, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func double(forKey key: String) -> Double? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.double(forKey: key)
    }

    func setDouble(_ value: Double, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func bool(forKey key: String) -> Bool? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.bool(forKey: key)
    }

    func setBool(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func setString(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func setData(_ value: Data, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
    }

    func allKeys() -> Set<String> {
        Set(defaults.dictionaryRepresentation().keys)
    }
}
