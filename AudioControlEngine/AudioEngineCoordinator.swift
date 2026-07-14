import AppKit
import Foundation
import DropThingsAudioControlKit

actor AudioEngineCoordinator {
    private struct RecentlyActiveApp {
        let identity: AudioAppIdentity
    }

    /// `kAudioProcessPropertyIsRunningOutput` can turn false while an app
    /// reconfigures a stream or is briefly silent. Keep a discovered app in
    /// the UI for the rest of its lifetime, but never keep it in the
    /// processing path unless it is actively outputting audio.
    private let catalog = CoreAudioCatalog()
    private let mediaRemote = DTMediaRemoteBridge()
    private var generation: UInt64 = 0
    private var activeSessionID: UUID?
    private var pipelines: [String: ProcessAudioPipeline] = [:]
    private var desiredByID: [String: AudioAppDesiredState] = [:]
    private var recentlyActiveApps: [String: RecentlyActiveApp] = [:]

    init() {
        catalog.cleanupOwnedAggregateDevices()
    }

    func apply(_ desired: AudioControlDesiredState) throws -> AudioControlObservedState {
        guard desired.protocolVersion == AudioControlProtocolVersion.current else {
            restoreNormalAudio()
            throw AudioControlProtocolError.incompatibleVersion(received: desired.protocolVersion)
        }
        guard desired.deadline >= Date() else { throw AudioControlProtocolError.expired }
        if activeSessionID != desired.sessionID {
            restoreNormalAudio()
            generation = 0
            activeSessionID = desired.sessionID
        }
        guard desired.generation >= generation else { throw AudioControlProtocolError.staleGeneration }
        generation = desired.generation
        desiredByID = Dictionary(uniqueKeysWithValues: desired.apps.map { ($0.identity.stableID, $0) })

        let processes = catalog.processes()
        let processByID = Dictionary(uniqueKeysWithValues: processes.map { ($0.identity.stableID, $0) })
        let anySolo = desired.apps.contains { $0.isSoloed && !$0.isIgnored }
        var failures: [String: String] = [:]

        for app in desired.apps {
            let id = app.identity.stableID
            let soloMuted = anySolo && !app.isSoloed
            let needsProcessing = !app.isIgnored && (app.requiresProcessing || soloMuted)
            guard needsProcessing else {
                pipelines.removeValue(forKey: id)?.stop()
                continue
            }
            guard let process = processByID[id], process.isRunningOutput else {
                pipelines.removeValue(forKey: id)?.stop()
                continue
            }
            let deviceUID = app.routeDeviceUID ?? catalog.defaultOutputUID()
            guard let deviceUID, catalog.audioObjectID(forDeviceUID: deviceUID) != nil else {
                failures[id] = "Selected output is unavailable; normal audio is restored."
                pipelines.removeValue(forKey: id)?.stop()
                continue
            }
            let effectiveGain: Float = (app.isMuted || soloMuted) ? 0 : Float(AudioSafetyPolicy.sanitizedGain(app.volume))
            if let current = pipelines[id], current.deviceUID == deviceUID {
                current.setGain(effectiveGain)
            } else {
                pipelines.removeValue(forKey: id)?.stop()
                do {
                    pipelines[id] = try ProcessAudioPipeline(
                        process: process,
                        deviceUID: deviceUID,
                        sessionID: desired.sessionID,
                        initialGain: effectiveGain
                    )
                } catch {
                    failures[id] = "Processing failed and was bypassed: \(error.localizedDescription)"
                }
            }
        }

        let desiredIDs = Set(desired.apps.map { $0.identity.stableID })
        for id in pipelines.keys where !desiredIDs.contains(id) {
            pipelines.removeValue(forKey: id)?.stop()
        }
        return snapshot(failures: failures)
    }

    func snapshot() -> AudioControlObservedState {
        snapshot(failures: [:])
    }

    func restoreNormalAudio() {
        let active = pipelines.values
        pipelines.removeAll()
        active.forEach { $0.stop() }
    }

    func sendMediaCommand(_ command: MediaTransportCommand) throws -> AudioControlObservedState {
        try mediaRemote.sendCommand(command.rawValue)
        return snapshot(failures: [:])
    }

    private func snapshot(failures: [String: String]) -> AudioControlObservedState {
        let processes = catalog.processes()
        let activeProcesses = processes.filter(\.isRunningOutput)
        for process in activeProcesses {
            recentlyActiveApps[process.identity.stableID] = RecentlyActiveApp(
                identity: process.identity
            )
        }

        recentlyActiveApps = recentlyActiveApps.filter { id, app in
            processes.contains { $0.identity.stableID == id }
                || catalog.isApplicationRunning(app.identity)
        }
        let activeByID = Dictionary(uniqueKeysWithValues: activeProcesses.map { ($0.identity.stableID, $0) })
        let apps = recentlyActiveApps.values
            .sorted { $0.identity.displayName.localizedCaseInsensitiveCompare($1.identity.displayName) == .orderedAscending }
            .map { cached -> AudioAppObservedState in
                let process = activeByID[cached.identity.stableID]
                let id = cached.identity.stableID
                let pipeline = pipelines[id]
                let desired = desiredByID[id]
                let health: AudioResourceHealth
                if let failure = failures[id] { health = .degraded(reason: failure) }
                else if pipeline != nil { health = .healthy }
                else { health = .bypassed }
                return AudioAppObservedState(
                    identity: cached.identity,
                    isProducingAudio: process != nil,
                    health: health,
                    peakLevel: pipeline?.peakLevel ?? 0,
                    appliedGain: pipeline == nil ? 1 : (desired?.isMuted == true ? 0 : desired?.volume ?? 1),
                    activeDeviceUID: pipeline?.deviceUID
                )
            }
        let engineHealth: AudioResourceHealth = failures.isEmpty
            ? (pipelines.isEmpty ? .bypassed : .healthy)
            : .degraded(reason: "One or more apps were safely bypassed.")
        return AudioControlObservedState(
            generation: generation,
            engineHealth: engineHealth,
            apps: apps,
            devices: catalog.devices(),
            defaultOutputUID: catalog.defaultOutputUID(),
            overloadCount: pipelines.values.reduce(0) { $0 + $1.overloadCount },
            mediaPlayback: currentMediaPlayback()
        )
    }

    private func currentMediaPlayback() -> MediaPlaybackState? {
        guard let raw = mediaRemote.snapshot(withTimeout: 0.75),
              let title = raw["title"] as? String,
              !title.isEmpty else { return nil }
        let pid = (raw["pid"] as? NSNumber)?.int32Value
        let application = pid.flatMap { NSRunningApplication(processIdentifier: $0) }
        let sourceBundleID = application?.bundleIdentifier
        let sourceDisplayName = application?.localizedName ?? sourceBundleID ?? "Media"
        return MediaPlaybackState(
            sourceBundleID: sourceBundleID,
            sourceDisplayName: sourceDisplayName,
            title: title,
            artist: raw["artist"] as? String,
            album: raw["album"] as? String,
            isPlaying: (raw["isPlaying"] as? NSNumber)?.boolValue ?? false
        )
    }
}
