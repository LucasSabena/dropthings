import Foundation

public enum TranscriptionEngineCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

public struct TranscriptionEngineAvailability: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let engineVersion: String

    public init(
        protocolVersion: Int = TranscriptionProtocol.currentVersion,
        engineVersion: String
    ) {
        self.protocolVersion = protocolVersion
        self.engineVersion = engineVersion
    }
}

public struct TranscriptionEngineFailure: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case invalidRequest
        case engineFailure
        case cancelled
    }

    public let kind: Kind
    public let message: String

    public init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }
}

/// The wire uses JSON `Data` so the XPC surface stays Objective-C-compatible
/// while all semantic types remain versioned Swift values.
@objc public protocol TranscriptionEngineXPCProtocol {
    func availability(reply: @escaping (Data?, Data?) -> Void)
    func transcribe(_ requestData: Data, reply: @escaping (Data?, Data?) -> Void)
    func cancel(_ jobID: String, reply: @escaping (Data?) -> Void)
}
