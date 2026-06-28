import XCTest
@testable import DropThingsCore

final class SettingsStoreTests: XCTestCase {
    private var backend: InMemorySettingsBackend!
    private var store: SettingsStore!

    override func setUp() {
        super.setUp()
        backend = InMemorySettingsBackend()
        store = SettingsStore(backend: backend)
    }

    func testIntegerRoundTrip() {
        let key = SettingsKey("test.int")
        XCTAssertEqual(store.integer(key, default: 7), 7)
        store.setInteger(42, key)
        XCTAssertEqual(store.integer(key, default: 7), 42)
    }

    func testBoolRoundTrip() {
        let key = SettingsKey("test.bool")
        XCTAssertEqual(store.bool(key, default: false), false)
        store.setBool(true, key)
        XCTAssertEqual(store.bool(key, default: false), true)
    }

    func testStringRoundTrip() {
        let key = SettingsKey("test.string")
        XCTAssertNil(store.string(key))
        store.setString("hello", key)
        XCTAssertEqual(store.string(key), "hello")
    }

    func testDataRoundTrip() {
        let key = SettingsKey("test.data")
        let payload = Data([0x01, 0x02, 0x03])
        XCTAssertNil(store.data(key))
        store.setData(payload, key)
        XCTAssertEqual(store.data(key), payload)
    }

    func testRemove() {
        let key = SettingsKey("test.remove")
        store.setString("present", key)
        XCTAssertEqual(store.string(key), "present")
        store.remove(key)
        XCTAssertNil(store.string(key))
    }

    func testMigrationRunsOnce() {
        var runs = 0
        let migration = SettingsMigration(fromVersion: 0) { backend in
            runs += 1
            backend.setBool(true, forKey: "migrated")
        }
        let storeWithMigration = SettingsStore(backend: backend, migrations: [migration])
        storeWithMigration.migrateIfNeeded()
        storeWithMigration.migrateIfNeeded()
        XCTAssertEqual(runs, 1, "Migration must not run twice for the same stored version")
        XCTAssertEqual(backend.bool(forKey: "migrated"), true)
    }
}
