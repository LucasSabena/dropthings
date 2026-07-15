import Foundation
import DropThingsCore
import DropThingsTranscriptionKit

public struct LocalTranscriptionSettings: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var selectedModel: TranscriptionModelID
    public var language: TranscriptionLanguage
    public var mode: TranscriptionMode
    public var outputFormats: Set<TranscriptOutputFormat>
    public var initialPrompt: String

    public init(
        version: Int = currentVersion,
        selectedModel: TranscriptionModelID = .base,
        language: TranscriptionLanguage = .automatic,
        mode: TranscriptionMode = .transcribe,
        outputFormats: Set<TranscriptOutputFormat> = [.text, .json],
        initialPrompt: String = ""
    ) {
        self.version = version
        self.selectedModel = selectedModel
        self.language = language
        self.mode = mode
        self.outputFormats = outputFormats
        self.initialPrompt = initialPrompt
        sanitize()
    }

    public mutating func sanitize() {
        version = Self.currentVersion
        if outputFormats.isEmpty { outputFormats = [.text] }
        initialPrompt = String(initialPrompt.prefix(2_000))
    }

    private enum CodingKeys: String, CodingKey {
        case version, selectedModel, language, mode, outputFormats, initialPrompt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            version: try container.decodeIfPresent(Int.self, forKey: .version) ?? 0,
            selectedModel: try container.decodeIfPresent(TranscriptionModelID.self, forKey: .selectedModel) ?? .base,
            language: try container.decodeIfPresent(TranscriptionLanguage.self, forKey: .language) ?? .automatic,
            mode: try container.decodeIfPresent(TranscriptionMode.self, forKey: .mode) ?? .transcribe,
            outputFormats: try container.decodeIfPresent(Set<TranscriptOutputFormat>.self, forKey: .outputFormats) ?? [.text, .json],
            initialPrompt: try container.decodeIfPresent(String.self, forKey: .initialPrompt) ?? ""
        )
    }
}

extension SettingsStore {
    private static let localTranscriptionKey = SettingsKey("modules.local-transcription.settings")

    public func loadLocalTranscriptionSettings() -> LocalTranscriptionSettings {
        guard let data = data(Self.localTranscriptionKey),
              var decoded = try? JSONDecoder().decode(LocalTranscriptionSettings.self, from: data) else {
            return LocalTranscriptionSettings()
        }
        decoded.sanitize()
        return decoded
    }

    public func saveLocalTranscriptionSettings(_ settings: LocalTranscriptionSettings) {
        var safe = settings
        safe.sanitize()
        guard let data = try? JSONEncoder().encode(safe) else { return }
        setData(data, Self.localTranscriptionKey)
    }
}
