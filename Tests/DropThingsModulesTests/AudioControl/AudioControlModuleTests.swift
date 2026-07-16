import XCTest
import DropThingsAudioControlKit
import DropThingsCore
import DropThingsPlatform
@testable import DropThingsModules

@MainActor
private final class FakeAudioControlEngine: AudioControlEngineClient {
    var onInterruption: (@MainActor @Sendable () -> Void)?
    private(set) var connectCount = 0
    private(set) var invalidateCount = 0
    private(set) var restoreCount = 0
    private(set) var applied: [AudioControlDesiredState] = []
    var state: AudioControlObservedState

    init(state: AudioControlObservedState) { self.state = state }

    func connect() { connectCount += 1 }
    func invalidate() { invalidateCount += 1 }
    func apply(_ desiredState: AudioControlDesiredState) async throws -> AudioControlObservedState {
        applied.append(desiredState)
        state = AudioControlObservedState(
            generation: desiredState.generation,
            engineHealth: .healthy,
            apps: state.apps,
            devices: state.devices,
            defaultOutputUID: state.defaultOutputUID
        )
        return state
    }
    func snapshot() async throws -> AudioControlObservedState { state }
    func restoreNormalAudio() async throws { restoreCount += 1 }
    func sendMediaCommand(_ command: MediaTransportCommand) async throws -> AudioControlObservedState { state }
}

private final class FakeSystemAudioOutput: SystemAudioOutputControlling {
    var stateByUID: [String: SystemAudioOutputState] = [:]
    private(set) var defaultOutputUID: String?
    private(set) var volumes: [(String, Double)] = []
    private(set) var mutes: [(String, Bool)] = []

    func state(forDeviceUID uid: String) throws -> SystemAudioOutputState {
        guard let state = stateByUID[uid] else { throw SystemAudioOutputError.deviceUnavailable }
        return state
    }

    func setDefaultOutput(deviceUID uid: String) throws { defaultOutputUID = uid }
    func setVolume(_ volume: Double, forDeviceUID uid: String) throws { volumes.append((uid, volume)) }
    func setMuted(_ muted: Bool, forDeviceUID uid: String) throws { mutes.append((uid, muted)) }
}

@MainActor
final class AudioControlModuleTests: XCTestCase {
    func testStartDiscoversWithoutApplyingAndStopRestoresAudio() async throws {
        let app = AudioAppIdentity(bundleID: "com.example.player", processFallback: nil, displayName: "Player")
        let observed = AudioControlObservedState(
            generation: 0,
            engineHealth: .bypassed,
            apps: [.init(identity: app, isProducingAudio: true, health: .bypassed)],
            devices: [],
            defaultOutputUID: nil
        )
        let engine = FakeAudioControlEngine(state: observed)
        let module = AudioControlModule(
            settings: SettingsStore(backend: InMemorySettingsBackend()),
            engine: engine
        )

        try await module.start()
        XCTAssertEqual(module.state, .running)
        XCTAssertEqual(engine.connectCount, 1)
        XCTAssertTrue(engine.applied.isEmpty, "Discovery must not start a tap or trigger permission")
        XCTAssertEqual(module.visibleApps.map(\.id), [app.stableID])

        await module.stop()
        XCTAssertEqual(engine.restoreCount, 1)
        XCTAssertEqual(engine.invalidateCount, 1)
        XCTAssertEqual(module.state, .off)
    }

    func testChangingVolumeSendsVersionedDesiredState() async throws {
        let app = AudioAppIdentity(bundleID: "com.example.player", processFallback: nil, displayName: "Player")
        let observed = AudioControlObservedState(
            generation: 0,
            engineHealth: .bypassed,
            apps: [.init(identity: app, isProducingAudio: true, health: .bypassed)],
            devices: [],
            defaultOutputUID: nil
        )
        let engine = FakeAudioControlEngine(state: observed)
        let module = AudioControlModule(settings: SettingsStore(backend: InMemorySettingsBackend()), engine: engine)
        try await module.start()

        module.setVolume(0.35, for: app)
        await Task.yield()

        XCTAssertEqual(engine.applied.last?.protocolVersion, AudioControlProtocolVersion.current)
        XCTAssertEqual(engine.applied.last?.apps.first?.volume, 0.35)
        XCTAssertTrue(engine.applied.last?.apps.first?.requiresProcessing == true)
        await module.stop()
    }

    func testSystemOutputControlsUseNarrowPlatformAdapter() async throws {
        let device = AudioDeviceIdentity(
            uid: "built-in",
            name: "MacBook Speakers",
            transport: "Built-in",
            sampleRate: 48_000,
            isAvailable: true,
            hasVolumeControl: true,
            isDefault: true
        )
        let engine = FakeAudioControlEngine(state: AudioControlObservedState(
            generation: 0,
            engineHealth: .bypassed,
            apps: [],
            devices: [device],
            defaultOutputUID: device.uid
        ))
        let output = FakeSystemAudioOutput()
        output.stateByUID[device.uid] = SystemAudioOutputState(
            deviceUID: device.uid,
            volume: 0.4,
            isMuted: false,
            canSetVolume: true,
            canSetMute: true
        )
        let module = AudioControlModule(
            settings: SettingsStore(backend: InMemorySettingsBackend()),
            engine: engine,
            systemOutput: output
        )

        try await module.start()
        XCTAssertEqual(module.menuBarIconName, "hifispeaker.fill")
        module.setSystemOutputVolume(0.65)
        XCTAssertEqual(module.menuBarIconName, "hifispeaker.fill")
        module.toggleSystemOutputMute()
        XCTAssertEqual(module.menuBarIconName, "hifispeaker.fill")

        XCTAssertEqual(module.systemOutputState?.volume, 0.65)
        XCTAssertEqual(output.volumes.first?.0, device.uid)
        XCTAssertEqual(output.volumes.first?.1, 0.65)
        XCTAssertEqual(output.mutes.first?.0, device.uid)
        XCTAssertEqual(output.mutes.first?.1, true)
        await module.stop()
    }

    func testPerAppRouteIsPersistedAndSentToEngine() async throws {
        let app = AudioAppIdentity(bundleID: "com.example.player", processFallback: nil, displayName: "Player")
        let engine = FakeAudioControlEngine(state: AudioControlObservedState(
            generation: 0,
            engineHealth: .bypassed,
            apps: [.init(identity: app, isProducingAudio: true, health: .bypassed)],
            devices: [],
            defaultOutputUID: nil
        ))
        let module = AudioControlModule(settings: SettingsStore(backend: InMemorySettingsBackend()), engine: engine)
        try await module.start()

        module.setRouteDeviceUID("usb-dac", for: app)
        await Task.yield()

        XCTAssertEqual(module.settings.appsByStableID[app.stableID]?.routeDeviceUID, "usb-dac")
        XCTAssertEqual(engine.applied.last?.apps.first?.routeDeviceUID, "usb-dac")
        await module.stop()
    }

    func testEveryOutputHasIndependentStateAndCanBecomeSystemDefault() async throws {
        let speakers = AudioDeviceIdentity(
            uid: "speakers", name: "Mac Speakers", transport: "Built-in",
            sampleRate: 48_000, isAvailable: true, hasVolumeControl: true, isDefault: true
        )
        let headphones = AudioDeviceIdentity(
            uid: "headphones", name: "Headphones", transport: "Bluetooth",
            sampleRate: 48_000, isAvailable: true, hasVolumeControl: true, isDefault: false
        )
        let engine = FakeAudioControlEngine(state: AudioControlObservedState(
            generation: 0, engineHealth: .bypassed, apps: [],
            devices: [speakers, headphones], defaultOutputUID: speakers.uid
        ))
        let output = FakeSystemAudioOutput()
        output.stateByUID = [
            speakers.uid: .init(deviceUID: speakers.uid, volume: 0.25, isMuted: false, canSetVolume: true, canSetMute: true),
            headphones.uid: .init(deviceUID: headphones.uid, volume: 0.8, isMuted: false, canSetVolume: true, canSetMute: true)
        ]
        let module = AudioControlModule(
            settings: SettingsStore(backend: InMemorySettingsBackend()),
            engine: engine,
            systemOutput: output
        )

        try await module.start()
        XCTAssertEqual(module.outputState(for: speakers.uid)?.volume, 0.25)
        XCTAssertEqual(module.outputState(for: headphones.uid)?.volume, 0.8)

        module.setOutputVolume(0.6, deviceUID: headphones.uid)
        module.setDefaultOutput(deviceUID: headphones.uid)

        XCTAssertEqual(output.volumes.last?.0, headphones.uid)
        XCTAssertEqual(output.volumes.last?.1, 0.6)
        XCTAssertEqual(output.defaultOutputUID, headphones.uid)
        XCTAssertEqual(module.activeOutputUID, headphones.uid)
        XCTAssertEqual(module.menuBarIconName, "headphones")
        await module.stop()
    }
}
