import XCTest
import DropThingsCore
@testable import DropThingsModules

@MainActor
final class MediaConverterModuleTests: XCTestCase {
    func testModuleIsExplicitlyBeta() {
        let module = MediaConverterModule(
            settings: SettingsStore(backend: InMemorySettingsBackend())
        )

        XCTAssertEqual(module.releaseStage, .beta)
    }
}
