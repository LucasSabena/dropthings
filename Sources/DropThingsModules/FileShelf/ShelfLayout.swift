import Foundation

/// How the shelf lays out its items. User-toggleable from the shelf header.
public enum ShelfLayout: String, Sendable, Codable, CaseIterable {
    case list
    case grid
}

/// Shake/flick detector sensitivity. Higher sensitivity lowers the
/// thresholds so a gentler gesture fires; lower sensitivity demands a
/// more deliberate one. The detector maps each level to concrete numbers.
public enum ShakeSensitivity: String, Sendable, Codable, CaseIterable {
    case low
    case medium
    case high
}
