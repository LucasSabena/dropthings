import Foundation
import DropThingsCore
import DropThingsAudioControlKit

public struct AudioControlAppSettings: Codable, Hashable, Sendable {
    public var identity: AudioAppIdentity
    public var volume: Double
    public var isMuted: Bool
    public var isSoloed: Bool
    public var isPinned: Bool
    public var isIgnored: Bool
    public var routeDeviceUID: String?

    public init(identity: AudioAppIdentity) {
        self.identity = identity
        volume = 1
        isMuted = false
        isSoloed = false
        isPinned = false
        isIgnored = false
        routeDeviceUID = nil
    }

    public var desiredState: AudioAppDesiredState {
        AudioAppDesiredState(
            identity: identity,
            volume: volume,
            isMuted: isMuted,
            isSoloed: isSoloed,
            isPinned: isPinned,
            isIgnored: isIgnored,
            routeDeviceUID: routeDeviceUID
        )
    }

    mutating func sanitize() {
        volume = AudioSafetyPolicy.sanitizedGain(volume)
        if isIgnored {
            isMuted = false
            isSoloed = false
            routeDeviceUID = nil
        }
    }
}

public struct AudioControlSettings: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var appsByStableID: [String: AudioControlAppSettings]
    public var showMeters: Bool
    public var showSystemProcesses: Bool

    public init(
        version: Int = currentVersion,
        appsByStableID: [String: AudioControlAppSettings] = [:],
        showMeters: Bool = true,
        showSystemProcesses: Bool = false
    ) {
        self.version = version
        self.appsByStableID = appsByStableID
        self.showMeters = showMeters
        self.showSystemProcesses = showSystemProcesses
        sanitize()
    }

    public mutating func settings(for identity: AudioAppIdentity) -> AudioControlAppSettings {
        if var current = appsByStableID[identity.stableID] {
            current.identity = identity
            current.sanitize()
            appsByStableID[identity.stableID] = current
            return current
        }
        let created = AudioControlAppSettings(identity: identity)
        appsByStableID[identity.stableID] = created
        return created
    }

    public mutating func update(_ settings: AudioControlAppSettings) {
        var safe = settings
        safe.sanitize()
        appsByStableID[safe.identity.stableID] = safe
    }

    public mutating func sanitize() {
        version = Self.currentVersion
        appsByStableID = Dictionary(uniqueKeysWithValues: appsByStableID.map { key, value in
            var safe = value
            safe.sanitize()
            return (key, safe)
        })
    }
}

extension SettingsStore {
    private static let audioControlKey = SettingsKey("modules.audio-control.settings")

    public func loadAudioControlSettings() -> AudioControlSettings {
        guard let data = data(Self.audioControlKey),
              var decoded = try? JSONDecoder().decode(AudioControlSettings.self, from: data) else {
            return AudioControlSettings()
        }
        decoded.sanitize()
        return decoded
    }

    public func saveAudioControlSettings(_ settings: AudioControlSettings) {
        var safe = settings
        safe.sanitize()
        guard let data = try? JSONEncoder().encode(safe) else { return }
        setData(data, Self.audioControlKey)
    }
}
