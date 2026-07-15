import AppKit
import Combine
import SwiftUI
import DropThingsAudioControlKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

@MainActor
public final class AudioControlModule: DropThingsModule {
    public let id = ModuleID.audioControl
    public let name = "Audio Control"
    public let summary = "Control volume and mute independently for each app."

    // System Audio Recording has no public preflight API. Enabling the module
    // performs read-only discovery only; macOS prompts when the user first
    // changes an app and the helper starts a process tap.
    public let requiredPermissions: [SystemPermission] = []

    @Published public private(set) var state: ModuleState = .off
    @Published public private(set) var settings: AudioControlSettings
    @Published public private(set) var observedState: AudioControlObservedState?
    @Published public private(set) var isRestoringNormalAudio = false
    @Published public private(set) var systemOutputState: SystemAudioOutputState?
    @Published public private(set) var outputStates: [String: SystemAudioOutputState] = [:]
    @Published public private(set) var activeOutputUID: String?
    @Published public private(set) var outputControlError: String?

    private let settingsStore: SettingsStore
    private let engine: any AudioControlEngineClient
    private let systemOutput: any SystemAudioOutputControlling
    private let sessionID = UUID()
    private var generation: UInt64 = 0
    private var refreshTask: Task<Void, Never>?
    private var restartFailures: [Date] = []
    private let crashPolicy = AudioEngineCrashPolicy()
    private let logger = ModuleLogger(subsystem: "app.dropthings", category: "audio-control")

    public init(
        settings: SettingsStore,
        engine: (any AudioControlEngineClient)? = nil,
        systemOutput: (any SystemAudioOutputControlling)? = nil
    ) {
        settingsStore = settings
        self.settings = settings.loadAudioControlSettings()
        self.engine = engine ?? XPCAudioControlEngineClient()
        self.systemOutput = systemOutput ?? CoreAudioSystemOutputController()
        self.engine.onInterruption = { [weak self] in self?.handleEngineInterruption() }
    }

    public var menuBarPresentation: ModuleMenuBarPresentation? {
        ModuleMenuBarPresentation(
            iconName: "speaker.wave.2.fill",
            accessibilityLabel: "Audio Control",
            preferredContentSize: CGSize(
                width: DTSize.moduleMenuBarWidth,
                height: DTSize.moduleMenuBarHeight
            ),
            isVisibleByDefault: true
        ) { [weak self] in
            guard let self else { return AnyView(EmptyView()) }
            return AnyView(AudioControlMenuBarView(module: self))
        }
    }

    public var menuBarIconName: String {
        guard let output = systemOutputState else { return "speaker.wave.2" }
        if output.isMuted || (output.volume ?? 0) <= 0.001 { return "speaker.slash.fill" }
        switch output.volume ?? 0 {
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    public func start() async throws {
        guard #available(macOS 15, *) else {
            state = .unavailable(reason: "Audio Control requires macOS 15 or later.")
            return
        }
        state = .starting
        engine.connect()
        do {
            observedState = try await engine.snapshot()
            generation = max(generation, observedState?.generation ?? 0)
            activeOutputUID = observedState?.defaultOutputUID
            refreshOutputStates()
            state = healthState(from: observedState?.engineHealth)
            startRefreshing()
        } catch {
            engine.invalidate()
            state = .failed(
                reason: "The isolated audio engine could not start: \(error.localizedDescription)",
                recovery: "Restore normal audio, then restart the engine."
            )
        }
    }

    public func stop() async {
        refreshTask?.cancel()
        refreshTask = nil
        do {
            try await engine.restoreNormalAudio()
        } catch {
            logger.error("Safe bypass during stop failed: \(error.localizedDescription)")
        }
        engine.invalidate()
        observedState = nil
        systemOutputState = nil
        outputStates = [:]
        activeOutputUID = nil
        state = .off
    }

    public func makeSettingsView() -> AnyView {
        AnyView(AudioControlSettingsView(module: self))
    }

    public var visibleApps: [AudioControlAppRow] {
        let observed = observedState?.apps ?? []
        var rows = Dictionary(uniqueKeysWithValues: observed.map { item in
            (item.identity.stableID, AudioControlAppRow(observed: item, settings: appSettings(for: item.identity)))
        })
        for saved in settings.appsByStableID.values where saved.isPinned {
            if rows[saved.identity.stableID] == nil {
                rows[saved.identity.stableID] = AudioControlAppRow(observed: nil, settings: saved)
            }
        }
        return rows.values
            .filter { settings.showSystemProcesses || $0.settings.identity.bundleID != nil }
            .filter { !$0.settings.isIgnored || $0.settings.isPinned }
            .sorted { lhs, rhs in
                if lhs.isProducingAudio != rhs.isProducingAudio { return lhs.isProducingAudio }
                if lhs.settings.isPinned != rhs.settings.isPinned { return lhs.settings.isPinned }
                return lhs.settings.identity.displayName.localizedCaseInsensitiveCompare(rhs.settings.identity.displayName) == .orderedAscending
            }
    }

    public var defaultOutput: AudioDeviceIdentity? {
        guard let uid = activeOutputUID ?? observedState?.defaultOutputUID else { return nil }
        return observedState?.devices.first { $0.uid == uid }
    }

    public var availableOutputs: [AudioDeviceIdentity] {
        let available = (observedState?.devices ?? []).filter(\.isAvailable)
        return Dictionary(grouping: available, by: \AudioDeviceIdentity.uid)
            .values
            .compactMap(\.first)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public var ignoredApps: [AudioControlAppSettings] {
        settings.appsByStableID.values
            .filter(\.isIgnored)
            .sorted { $0.identity.displayName.localizedCaseInsensitiveCompare($1.identity.displayName) == .orderedAscending }
    }

    public func setVolume(_ volume: Double, for identity: AudioAppIdentity) {
        update(identity) { $0.volume = volume }
    }

    public func setRouteDeviceUID(_ deviceUID: String?, for identity: AudioAppIdentity) {
        update(identity) { $0.routeDeviceUID = deviceUID }
    }

    public func setDefaultOutput(deviceUID: String) {
        guard deviceUID != activeOutputUID else { return }
        do {
            try systemOutput.setDefaultOutput(deviceUID: deviceUID)
            activeOutputUID = deviceUID
            systemOutputState = outputStates[deviceUID]
            outputControlError = nil
            Task { @MainActor [weak self] in await self?.reloadObservedState() }
        } catch {
            outputControlError = error.localizedDescription
        }
    }

    public func setSystemOutputVolume(_ volume: Double) {
        guard let uid = activeOutputUID else { return }
        setOutputVolume(volume, deviceUID: uid)
    }

    public func outputState(for deviceUID: String) -> SystemAudioOutputState? {
        outputStates[deviceUID]
    }

    public func setOutputVolume(_ volume: Double, deviceUID: String) {
        guard let previous = outputStates[deviceUID] else { return }
        let updated = SystemAudioOutputState(
            deviceUID: deviceUID,
            volume: max(0, min(1, volume)),
            isMuted: previous.isMuted,
            canSetVolume: previous.canSetVolume,
            canSetMute: previous.canSetMute
        )
        outputStates[deviceUID] = updated
        if deviceUID == activeOutputUID { systemOutputState = updated }
        do {
            try systemOutput.setVolume(volume, forDeviceUID: deviceUID)
            outputControlError = nil
        } catch {
            outputStates[deviceUID] = previous
            if deviceUID == activeOutputUID { systemOutputState = previous }
            outputControlError = error.localizedDescription
        }
    }

    public func toggleSystemOutputMute() {
        guard let uid = activeOutputUID else { return }
        toggleOutputMute(deviceUID: uid)
    }

    public func toggleOutputMute(deviceUID: String) {
        guard let current = outputStates[deviceUID] else { return }
        do {
            try systemOutput.setMuted(!current.isMuted, forDeviceUID: deviceUID)
            let updated = SystemAudioOutputState(
                deviceUID: deviceUID,
                volume: current.volume,
                isMuted: !current.isMuted,
                canSetVolume: current.canSetVolume,
                canSetMute: current.canSetMute
            )
            outputStates[deviceUID] = updated
            if deviceUID == activeOutputUID { systemOutputState = updated }
            outputControlError = nil
        } catch {
            outputControlError = error.localizedDescription
        }
    }

    public func toggleMute(for identity: AudioAppIdentity) {
        update(identity) { $0.isMuted.toggle() }
    }

    public func toggleSolo(for identity: AudioAppIdentity) {
        update(identity) { $0.isSoloed.toggle() }
    }

    public func sendMediaCommand(_ command: MediaTransportCommand) {
        guard state.isStarted else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                self.observedState = try await self.engine.sendMediaCommand(command)
                self.activeOutputUID = self.observedState?.defaultOutputUID
                self.refreshOutputStates()
                self.outputControlError = nil
            } catch {
                self.outputControlError = error.localizedDescription
            }
        }
    }

    public func togglePin(for identity: AudioAppIdentity) {
        update(identity) { $0.isPinned.toggle() }
    }

    public func setIgnored(_ ignored: Bool, for identity: AudioAppIdentity) {
        update(identity) { $0.isIgnored = ignored }
    }

    public func pinApplication(at url: URL) {
        let bundle = Bundle(url: url)
        let bundleID = bundle?.bundleIdentifier
        let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let identity = AudioAppIdentity(bundleID: bundleID, processFallback: url.path, displayName: name)
        update(identity) { $0.isPinned = true }
    }

    public func reset(_ identity: AudioAppIdentity) {
        var reset = AudioControlAppSettings(identity: identity)
        reset.isPinned = appSettings(for: identity).isPinned
        settings.update(reset)
        persistAndApply()
    }

    public func setShowMeters(_ enabled: Bool) {
        settings.showMeters = enabled
        settingsStore.saveAudioControlSettings(settings)
    }

    public func setShowSystemProcesses(_ enabled: Bool) {
        settings.showSystemProcesses = enabled
        settingsStore.saveAudioControlSettings(settings)
        objectWillChange.send()
    }

    public func restoreNormalAudio() {
        guard !isRestoringNormalAudio else { return }
        isRestoringNormalAudio = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isRestoringNormalAudio = false }
            do {
                try await self.engine.restoreNormalAudio()
                self.observedState = try await self.engine.snapshot()
                self.activeOutputUID = self.observedState?.defaultOutputUID
                self.refreshOutputStates()
                self.state = .running
            } catch {
                self.state = .failed(
                    reason: "Could not verify normal audio restoration: \(error.localizedDescription)",
                    recovery: "Quit DropThings. The private helper and its private resources terminate with it."
                )
            }
        }
    }

    public func restartEngine() {
        refreshTask?.cancel()
        engine.invalidate()
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await self.start()
        }
    }

#if DEBUG
    /// Stable populated state used only by the app shell's visual-QA launch flag.
    /// Release builds never contain synthetic audio observations.
    public func prepareEmptyVisualTestingState() {
        refreshTask?.cancel()
        refreshTask = nil
        let builtIn = AudioDeviceIdentity(
            uid: "visual-testing-built-in-output",
            name: "MacBook Air Speakers",
            transport: "Built-in",
            sampleRate: 48_000,
            isAvailable: true,
            hasVolumeControl: true,
            isDefault: false
        )
        let headphones = AudioDeviceIdentity(
            uid: "visual-testing-headphones",
            name: "EDIFIER ES850NB",
            transport: "Bluetooth",
            sampleRate: 48_000,
            isAvailable: true,
            hasVolumeControl: true,
            isDefault: true
        )
        let whatsapp = AudioAppIdentity(
            bundleID: "net.whatsapp.WhatsApp",
            processFallback: nil,
            displayName: "WhatsApp"
        )
        observedState = AudioControlObservedState(
            generation: generation,
            engineHealth: .bypassed,
            apps: [
                AudioAppObservedState(
                    identity: whatsapp,
                    isProducingAudio: true,
                    health: .healthy,
                    peakLevel: 0.72,
                    appliedGain: 1,
                    activeDeviceUID: headphones.uid
                )
            ],
            devices: [builtIn, headphones],
            defaultOutputUID: headphones.uid,
            mediaPlayback: MediaPlaybackState(
                sourceBundleID: whatsapp.bundleID,
                sourceDisplayName: "WhatsApp",
                title: "Voice message",
                artist: "Now playing",
                isPlaying: true
            )
        )
        systemOutputState = SystemAudioOutputState(
            deviceUID: headphones.uid,
            volume: 1,
            isMuted: false,
            canSetVolume: true,
            canSetMute: true
        )
        activeOutputUID = headphones.uid
        outputStates = [
            builtIn.uid: SystemAudioOutputState(
                deviceUID: builtIn.uid,
                volume: 0.25,
                isMuted: false,
                canSetVolume: true,
                canSetMute: true
            ),
            headphones.uid: systemOutputState!
        ]
        outputControlError = nil
        state = .running
    }
#endif

    private func appSettings(for identity: AudioAppIdentity) -> AudioControlAppSettings {
        settings.appsByStableID[identity.stableID] ?? AudioControlAppSettings(identity: identity)
    }

    private func update(_ identity: AudioAppIdentity, mutation: (inout AudioControlAppSettings) -> Void) {
        var app = appSettings(for: identity)
        app.identity = identity
        mutation(&app)
        settings.update(app)
        persistAndApply()
    }

    private func persistAndApply() {
        settingsStore.saveAudioControlSettings(settings)
        Task { @MainActor [weak self] in await self?.applyDesiredState() }
    }

    private func applyDesiredState() async {
        guard state.isStarted else { return }
        generation &+= 1
        let desired = AudioControlDesiredState(
            generation: generation,
            deadline: Date().addingTimeInterval(5),
            sessionID: sessionID,
            apps: settings.appsByStableID.values.map(\.desiredState)
        )
        do {
            let observed = try await engine.apply(desired)
            guard observed.generation >= generation else { return }
            observedState = observed
            activeOutputUID = observed.defaultOutputUID
            refreshOutputStates()
            state = healthState(from: observed.engineHealth)
        } catch {
            state = .failed(
                reason: "Audio changes were bypassed: \(error.localizedDescription)",
                recovery: "Restore normal audio, then restart the engine."
            )
        }
    }

    private func startRefreshing() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                await self.applyDesiredState()
                if case .failed = self.state { return }
            }
        }
    }

    private func reloadObservedState() async {
        do {
            observedState = try await engine.snapshot()
            activeOutputUID = observedState?.defaultOutputUID
            refreshOutputStates()
            if let health = observedState?.engineHealth {
                state = healthState(from: health)
            }
        } catch {
            outputControlError = error.localizedDescription
        }
    }

    private func refreshOutputStates() {
        var refreshed: [String: SystemAudioOutputState] = [:]
        for device in availableOutputs {
            if let state = try? systemOutput.state(forDeviceUID: device.uid) {
                refreshed[device.uid] = state
            }
        }
        outputStates = refreshed
        guard let uid = activeOutputUID ?? observedState?.defaultOutputUID else {
            systemOutputState = nil
            return
        }
        if let state = refreshed[uid] {
            systemOutputState = state
            outputControlError = nil
        } else {
            systemOutputState = nil
            outputControlError = "The active audio output is unavailable."
        }
    }

    private func handleEngineInterruption() {
        refreshTask?.cancel()
        observedState = nil
        restartFailures.append(Date())
        switch crashPolicy.decision(after: restartFailures) {
        case .cutoff:
            state = .failed(
                reason: "The isolated audio engine stopped repeatedly. Automatic restart is disabled.",
                recovery: "Restore normal audio and restart manually."
            )
        case .restart(let delay):
            state = .degraded(reason: "The isolated audio engine stopped. Normal audio is being restored before restart.")
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self else { return }
                try? await self.start()
            }
        }
    }

    private func healthState(from health: AudioResourceHealth?) -> ModuleState {
        switch health {
        case .healthy, .bypassed: return .running
        case .degraded(let reason): return .degraded(reason: reason)
        case .failed(let reason): return .failed(reason: reason, recovery: "Restore normal audio and restart the engine.")
        case nil: return .starting
        }
    }
}

public struct AudioControlAppRow: Identifiable, Sendable {
    public let observed: AudioAppObservedState?
    public let settings: AudioControlAppSettings

    public var id: String { settings.identity.stableID }
    public var isProducingAudio: Bool { observed?.isProducingAudio == true }
}
