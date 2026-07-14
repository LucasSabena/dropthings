import Foundation

public enum AudioControlProtocolVersion {
    public static let current = 1
}

public struct AudioAppIdentity: Codable, Hashable, Sendable, Identifiable {
    public let stableID: String
    public let bundleID: String?
    public let processFallback: String?
    public let displayName: String

    public var id: String { stableID }

    public init(bundleID: String?, processFallback: String?, displayName: String) {
        self.bundleID = bundleID
        self.processFallback = processFallback
        self.displayName = displayName
        if let bundleID, !bundleID.isEmpty {
            stableID = "bundle:\(bundleID)"
        } else {
            stableID = "process:\(processFallback ?? displayName)"
        }
    }
}

public struct AudioDeviceIdentity: Codable, Hashable, Sendable, Identifiable {
    public let uid: String
    public let name: String
    public let transport: String
    public let sampleRate: Double
    public let isAvailable: Bool
    public let hasVolumeControl: Bool
    public let isDefault: Bool

    public var id: String { uid }

    public init(
        uid: String,
        name: String,
        transport: String,
        sampleRate: Double,
        isAvailable: Bool,
        hasVolumeControl: Bool,
        isDefault: Bool
    ) {
        self.uid = uid
        self.name = name
        self.transport = transport
        self.sampleRate = sampleRate
        self.isAvailable = isAvailable
        self.hasVolumeControl = hasVolumeControl
        self.isDefault = isDefault
    }
}

public struct AudioAppDesiredState: Codable, Hashable, Sendable {
    public let identity: AudioAppIdentity
    public let volume: Double
    public let isMuted: Bool
    public let isSoloed: Bool
    public let isPinned: Bool
    public let isIgnored: Bool
    public let routeDeviceUID: String?

    public init(
        identity: AudioAppIdentity,
        volume: Double = 1,
        isMuted: Bool = false,
        isSoloed: Bool = false,
        isPinned: Bool = false,
        isIgnored: Bool = false,
        routeDeviceUID: String? = nil
    ) {
        self.identity = identity
        self.volume = AudioSafetyPolicy.sanitizedGain(volume)
        self.isMuted = isMuted
        self.isSoloed = isSoloed
        self.isPinned = isPinned
        self.isIgnored = isIgnored
        self.routeDeviceUID = routeDeviceUID
    }

    public var requiresProcessing: Bool {
        !isIgnored && (isMuted || isSoloed || abs(volume - 1) > 0.000_1 || routeDeviceUID != nil)
    }
}

public struct AudioControlDesiredState: Codable, Hashable, Sendable {
    public let protocolVersion: Int
    public let generation: UInt64
    public let deadline: Date
    public let sessionID: UUID
    public let apps: [AudioAppDesiredState]

    public init(
        generation: UInt64,
        deadline: Date,
        sessionID: UUID,
        apps: [AudioAppDesiredState],
        protocolVersion: Int = AudioControlProtocolVersion.current
    ) {
        self.protocolVersion = protocolVersion
        self.generation = generation
        self.deadline = deadline
        self.sessionID = sessionID
        self.apps = apps
    }
}

public enum AudioResourceHealth: Codable, Hashable, Sendable {
    case healthy
    case bypassed
    case degraded(reason: String)
    case failed(reason: String)
}

public struct AudioAppObservedState: Codable, Hashable, Sendable, Identifiable {
    public let identity: AudioAppIdentity
    public let isProducingAudio: Bool
    public let health: AudioResourceHealth
    public let peakLevel: Float
    public let appliedGain: Double
    public let activeDeviceUID: String?

    public var id: String { identity.id }

    public init(
        identity: AudioAppIdentity,
        isProducingAudio: Bool,
        health: AudioResourceHealth,
        peakLevel: Float = 0,
        appliedGain: Double = 1,
        activeDeviceUID: String? = nil
    ) {
        self.identity = identity
        self.isProducingAudio = isProducingAudio
        self.health = health
        self.peakLevel = max(0, min(1, peakLevel.isFinite ? peakLevel : 0))
        self.appliedGain = AudioSafetyPolicy.sanitizedGain(appliedGain)
        self.activeDeviceUID = activeDeviceUID
    }
}

public enum MediaTransportCommand: Int, Codable, Hashable, Sendable {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}

/// Metadata published by the system's active Now Playing session. It is
/// intentionally separate from process-audio discovery: a session can exist
/// while the corresponding stream is momentarily silent.
public struct MediaPlaybackState: Codable, Hashable, Sendable {
    public let sourceBundleID: String?
    public let sourceDisplayName: String
    public let title: String
    public let artist: String?
    public let album: String?
    public let isPlaying: Bool

    public init(
        sourceBundleID: String?,
        sourceDisplayName: String,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        isPlaying: Bool
    ) {
        self.sourceBundleID = sourceBundleID
        self.sourceDisplayName = sourceDisplayName
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
    }
}

public struct AudioControlObservedState: Codable, Hashable, Sendable {
    public let protocolVersion: Int
    public let generation: UInt64
    public let engineHealth: AudioResourceHealth
    public let apps: [AudioAppObservedState]
    public let devices: [AudioDeviceIdentity]
    public let defaultOutputUID: String?
    public let overloadCount: UInt64
    public let mediaPlayback: MediaPlaybackState?

    public init(
        generation: UInt64,
        engineHealth: AudioResourceHealth,
        apps: [AudioAppObservedState],
        devices: [AudioDeviceIdentity],
        defaultOutputUID: String?,
        overloadCount: UInt64 = 0,
        mediaPlayback: MediaPlaybackState? = nil,
        protocolVersion: Int = AudioControlProtocolVersion.current
    ) {
        self.protocolVersion = protocolVersion
        self.generation = generation
        self.engineHealth = engineHealth
        self.apps = apps
        self.devices = devices
        self.defaultOutputUID = defaultOutputUID
        self.overloadCount = overloadCount
        self.mediaPlayback = mediaPlayback
    }
}

public enum AudioControlProtocolError: LocalizedError, Equatable, Sendable {
    case incompatibleVersion(received: Int)
    case expired
    case staleGeneration

    public var errorDescription: String? {
        switch self {
        case .incompatibleVersion(let received): return "Incompatible audio protocol version \(received)."
        case .expired: return "The audio request expired before it could be applied."
        case .staleGeneration: return "The audio request was older than the engine state."
        }
    }
}

public enum AudioControlCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

@objc public protocol AudioControlXPCServiceProtocol {
    func applyDesiredState(_ data: Data, reply: @escaping (Data?, String?) -> Void)
    func snapshot(reply: @escaping (Data?, String?) -> Void)
    func restoreNormalAudio(reply: @escaping (String?) -> Void)
    func sendMediaCommand(_ command: Int, reply: @escaping (Data?, String?) -> Void)
}
