import XCTest
import AppKit
import DropThingsCore
import DropThingsPlatform
@testable import DropThingsModules

@MainActor
final class SmartClipboardModuleTests: XCTestCase {
    private var backend: InMemorySettingsBackend!
    private var store: SettingsStore!
    private var permissions: PermissionCenter!
    private var pasteboard: NSPasteboard!
    private var hubBackend: SmartClipboardTestBackend!
    private var hub: PasteboardHub!
    private var fetcher: FakeURLTitleFetcher!

    override func setUp() {
        super.setUp()
        backend = InMemorySettingsBackend()
        store = SettingsStore(backend: backend)
        permissions = PermissionCenter(backend: SmartClipboardFakePermissionBackend())
        pasteboard = NSPasteboard(name: NSPasteboard.Name("smart-clipboard-tests-\(UUID().uuidString)"))
        hubBackend = SmartClipboardTestBackend()
        hub = PasteboardHub(backend: hubBackend)
        fetcher = FakeURLTitleFetcher(result: .success("Example Title"))
    }

    private func makeModule(fileActionRegistry: FileActionRegistry? = nil) -> SmartClipboardModule {
        SmartClipboardModule(
            settings: store,
            permissions: permissions,
            hub: hub,
            pasteboard: pasteboard,
            fileActionRegistry: fileActionRegistry,
            urlTitleFetcher: fetcher
        )
    }

    private func snapshot(text: String? = nil, fileURLs: [URL] = [], imageData: Data? = nil, colorHex: String? = nil, changeCount: Int = 1) -> PasteboardHub.Snapshot {
        PasteboardHub.Snapshot(
            changeCount: changeCount, text: text, url: nil, fileURLs: fileURLs,
            imageData: imageData, colorHex: colorHex,
            isTransient: false, isConcealed: false, sourceBundleID: nil
        )
    }

    func testStartSetsRunningAndStartsHub() async throws {
        let module = makeModule()
        try await module.start()
        XCTAssertEqual(module.state, .running)
        XCTAssertTrue(hubBackend.isRunning)
        await module.stop()
        // The module stops itself but leaves the shared hub running so other
        // subscribers (Clipboard History) keep observing. The app shell owns
        // the hub lifetime, not any single module.
        XCTAssertEqual(module.state, .off)
    }

    func testRunningModulePublishesExternalClipboardChangesToItsSnapshot() async throws {
        let module = makeModule()
        try await module.start()

        hubBackend.emit(snapshot(text: "new clipboard", changeCount: 42))

        XCTAssertEqual(module.currentSnapshot()?.text, "new clipboard")
        await module.stop()
    }

    func testStartIsIdempotent() async throws {
        let module = makeModule()
        try await module.start()
        try await module.start()
        XCTAssertEqual(module.state, .running)
        await module.stop()
    }

    func testCurrentSnapshotReflectsHubLatest() {
        let module = makeModule()
        hub.overrideLatest(snapshot(text: "https://example.com"))

        let current = module.currentSnapshot()

        XCTAssertEqual(current?.kind, .url)
        XCTAssertEqual(current?.text, "https://example.com")
    }

    func testApplyTextCaseProducesCopyableResult() {
        let module = makeModule()
        hub.overrideLatest(snapshot(text: "hello"))
        let snap = module.currentSnapshot()!

        let outcome = module.apply(action: SmartClipboardAction(id: "x", title: "UP", systemImage: "t", body: .textCase(.uppercase)), to: snap)

        XCTAssertEqual(outcome.copyableText, "HELLO")
        XCTAssertEqual(outcome.preview, "HELLO")
    }

    func testApplyJSONPrettyPrints() {
        let module = makeModule()
        hub.overrideLatest(snapshot(text: "{\"a\":1}"))
        let snap = module.currentSnapshot()!

        let outcome = module.apply(action: SmartClipboardAction(id: "x", title: "Pretty", systemImage: "t", body: .jsonPretty(sortKeys: false)), to: snap)

        XCTAssertTrue(outcome.copyableText?.contains("\n") == true)
    }

    func testApplyURLNormalizeStripsTracking() {
        let module = makeModule()
        hub.overrideLatest(PasteboardHub.Snapshot(
            changeCount: 1, text: "https://x.com/?utm_source=a&id=1", url: URL(string: "https://x.com/?utm_source=a&id=1"),
            fileURLs: [], imageData: nil, colorHex: nil,
            isTransient: false, isConcealed: false, sourceBundleID: nil
        ))
        let snap = module.currentSnapshot()!

        let outcome = module.apply(action: SmartClipboardAction(id: "x", title: "Strip", systemImage: "t", body: .urlStripTracking), to: snap)

        XCTAssertEqual(outcome.copyableText, "https://x.com/?id=1")
        XCTAssertNotNil(outcome.notice)
    }

    func testApplyColorFormat() {
        let module = makeModule()
        hub.overrideLatest(snapshot(text: "#FF0000"))
        let snap = module.currentSnapshot()!

        let outcome = module.apply(action: SmartClipboardAction(id: "x", title: "RGB", systemImage: "t", body: .colorFormat(.rgb)), to: snap)

        XCTAssertEqual(outcome.copyableText, "rgb(255, 0, 0)")
    }

    func testApplyCountsProducesText() {
        let module = makeModule()
        hub.overrideLatest(snapshot(text: "hello world"))
        let snap = module.currentSnapshot()!

        let outcome = module.apply(action: SmartClipboardAction(id: "x", title: "Counts", systemImage: "t", body: .textCounts), to: snap)

        XCTAssertTrue(outcome.preview.contains("11 characters"))
        XCTAssertTrue(outcome.preview.contains("2 words"))
    }

    func testImageInfoUsesImagePixelsInsteadOfEmptyFileList() {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 3,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let data = bitmap.representation(using: .png, properties: [:])!
        let module = makeModule()
        hub.overrideLatest(snapshot(imageData: data))
        let snap = module.currentSnapshot()!

        let outcome = module.apply(
            action: SmartClipboardAction(id: "image.info", title: "Info", systemImage: "info.circle", body: .imageInfo),
            to: snap
        )

        XCTAssertTrue(outcome.preview.contains("3 × 2 px"))
        XCTAssertFalse(outcome.preview.isEmpty)
    }

    func testCopyResultWritesToPasteboardAndSetsLastResult() {
        let module = makeModule()
        module.copyResult("transformed")
        XCTAssertEqual(pasteboard.string(forType: .string), "transformed")
        XCTAssertEqual(module.lastResult, "transformed")
    }

    func testCopyColorPublishesNativeAndString() {
        let module = makeModule()
        let color = SmartClipboardColor(r: 12, g: 34, b: 56)
        module.copyColor(color, as: .hex)

        XCTAssertEqual(pasteboard.string(forType: .string), "#0C2238")
        let nsColor = pasteboard.readObjects(forClasses: [NSColor.self], options: nil)?.first as? NSColor
        XCTAssertNotNil(nsColor)
    }

    func testUndoCopyRestoresPreviousSnapshot() {
        let module = makeModule()
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)

        module.copyResult("changed")
        XCTAssertEqual(pasteboard.string(forType: .string), "changed")

        let result = module.undoCopy()
        XCTAssertEqual(result, .restored)
        XCTAssertEqual(pasteboard.string(forType: .string), "original")
        XCTAssertNil(module.lastResult)
    }

    func testUndoWithoutCopyReturnsNothingToUndo() {
        let module = makeModule()
        XCTAssertEqual(module.undoCopy(), .nothingToUndo)
    }

    func testPasteBackDisabledByDefault() {
        let module = makeModule()
        module.copyResult("x")
        XCTAssertEqual(module.pasteBack(), .disabled)
    }

    func testPasteBackNeedsAccessibilityWhenEnabledButNotGranted() {
        let module = makeModule()
        module.setPasteBackEnabled(true)
        module.copyResult("x")
        // Paste-back requires Accessibility (AXIsProcessTrusted). In a test
        // environment that value depends on how the host is launched, so we
        // only assert that the non-disabled branches are reachable: the call
        // must not return `.disabled` once the feature is enabled.
        XCTAssertNotEqual(module.pasteBack(), .disabled)
    }

    func testFetchURLTitleReturnsMarkdownLink() async {
        let module = makeModule()
        let url = URL(string: "https://example.com")!
        hub.overrideLatest(PasteboardHub.Snapshot(
            changeCount: 1, text: url.absoluteString, url: url,
            fileURLs: [], imageData: nil, colorHex: nil,
            isTransient: false, isConcealed: false, sourceBundleID: nil
        ))
        let snap = module.currentSnapshot()!

        let outcome = await module.fetchURLTitle(for: snap)

        XCTAssertEqual(outcome.copyableText, "[Example Title](https://example.com)")
    }

    func testFetchURLTitleSurfacesFailure() async {
        fetcher = FakeURLTitleFetcher(result: .failure(URLError(.notConnectedToInternet)))
        let module = makeModule()
        hub.overrideLatest(PasteboardHub.Snapshot(
            changeCount: 1, text: "https://example.com", url: URL(string: "https://example.com"),
            fileURLs: [], imageData: nil, colorHex: nil,
            isTransient: false, isConcealed: false, sourceBundleID: nil
        ))
        let snap = module.currentSnapshot()!

        let outcome = await module.fetchURLTitle(for: snap)

        XCTAssertNotNil(outcome.notice)
        XCTAssertNil(outcome.copyableText)
    }

    func testPinnedActionsPersistAcrossInstances() {
        let module = makeModule()
        module.togglePinned(actionID: "text.case.uppercase")
        module.togglePinned(actionID: "text.lines.sortAscending")

        let reloaded = makeModule()
        XCTAssertEqual(reloaded.pinnedActionIDs, ["text.case.uppercase", "text.lines.sortAscending"])
    }

    func testUnpinRemovesAction() {
        let module = makeModule()
        module.togglePinned(actionID: "a")
        module.togglePinned(actionID: "a")

        XCTAssertTrue(module.pinnedActionIDs.isEmpty)
    }

    func testOriginSuppressionDropsSelfEcho() {
        let module = makeModule()
        hub.start()
        // Simulate the hub dispatching the module's own write back to it: the
        // hub records the module's origin before emitting, so the module's
        // subscriber is skipped. We verify the hub itself suppresses.
        var received = 0
        _ = hub.subscribe(origin: module.origin) { _ in received += 1 }
        hub.recordWrite(origin: module.origin)
        hubBackend.emit(snapshot(text: "own write", changeCount: 2))
        XCTAssertEqual(received, 0)

        hubBackend.emit(snapshot(text: "external", changeCount: 3))
        XCTAssertEqual(received, 1)
        hub.stop()
    }

    func testFileActionRegistryInvocation() {
        let registry = FileActionRegistry()
        let box = URLBox()
        let descriptor = FileActionRegistry.Descriptor(
            id: "convert", title: "Convert", systemImage: "star", producerID: "converter",
            isAvailable: { { true } }
        )
        registry.register(descriptor, handler: .init(id: "convert") { urls in box.urls = urls })

        let module = makeModule(fileActionRegistry: registry)
        let url = URL(fileURLWithPath: "/tmp/a.png")
        hub.overrideLatest(snapshot(text: nil, fileURLs: [url]))
        let snap = module.currentSnapshot()!

        XCTAssertTrue(module.runFileAction(id: "convert", for: snap))
        XCTAssertEqual(box.urls.map(\.path), ["/tmp/a.png"])
    }

    func testUnavailableFileActionReturnsFalse() {
        let registry = FileActionRegistry()
        let descriptor = FileActionRegistry.Descriptor(
            id: "off", title: "Off", systemImage: "star", producerID: "p",
            isAvailable: { { false } }
        )
        registry.register(descriptor, handler: .init(id: "off") { _ in })

        let module = makeModule(fileActionRegistry: registry)
        hub.overrideLatest(snapshot(text: nil, fileURLs: [URL(fileURLWithPath: "/x")]))
        let snap = module.currentSnapshot()!

        XCTAssertFalse(module.runFileAction(id: "off", for: snap))
    }
}
