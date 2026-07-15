import XCTest
@testable import DropThingsCore

@MainActor
final class FileActionRegistryTests: XCTestCase {
    private func makeDescriptor(id: String, available: Bool) -> FileActionRegistry.Descriptor {
        FileActionRegistry.Descriptor(
            id: id,
            title: id,
            systemImage: "star",
            producerID: "test",
            isAvailable: { { available } }
        )
    }

    func testRegisterAndRunInvokesHandler() {
        let registry = FileActionRegistry()
        var called: [URL] = []
        let descriptor = makeDescriptor(id: "open", available: true)
        registry.register(descriptor, handler: FileActionRegistry.ActionHandler(id: "open") { urls in
            called = urls
        })

        let ran = registry.run(id: "open", for: [URL(fileURLWithPath: "/tmp/a")])

        XCTAssertTrue(ran)
        XCTAssertEqual(called.map(\.path), ["/tmp/a"])
    }

    func testUnavailableActionIsHiddenAndNotRun() {
        let registry = FileActionRegistry()
        registry.register(makeDescriptor(id: "off", available: false),
                          handler: .init(id: "off") { _ in })

        XCTAssertTrue(registry.availableActions().isEmpty)
        XCTAssertFalse(registry.run(id: "off", for: []))
    }

    func testUnregisterRemovesAction() {
        let registry = FileActionRegistry()
        registry.register(makeDescriptor(id: "x", available: true), handler: .init(id: "x") { _ in })
        registry.unregister(id: "x")

        XCTAssertTrue(registry.descriptors.isEmpty)
        XCTAssertFalse(registry.run(id: "x", for: []))
    }

    func testUnregisterProducerRemovesAllFromProducer() {
        let registry = FileActionRegistry()
        let d1 = FileActionRegistry.Descriptor(id: "a", title: "A", systemImage: "s", producerID: "p1", isAvailable: { { true } })
        let d2 = FileActionRegistry.Descriptor(id: "b", title: "B", systemImage: "s", producerID: "p1", isAvailable: { { true } })
        let d3 = FileActionRegistry.Descriptor(id: "c", title: "C", systemImage: "s", producerID: "p2", isAvailable: { { true } })
        registry.register(d1, handler: .init(id: "a") { _ in })
        registry.register(d2, handler: .init(id: "b") { _ in })
        registry.register(d3, handler: .init(id: "c") { _ in })

        registry.unregisterProducer("p1")

        XCTAssertEqual(registry.descriptors.map(\.id), ["c"])
    }

    func testReferencesOnlyIncludeAvailableActions() {
        let registry = FileActionRegistry()
        registry.register(makeDescriptor(id: "on", available: true), handler: .init(id: "on") { _ in })
        registry.register(makeDescriptor(id: "off", available: false), handler: .init(id: "off") { _ in })

        let refs = registry.references()
        XCTAssertEqual(refs.map(\.id), ["on"])
    }
}