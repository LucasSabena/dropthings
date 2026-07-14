import Foundation

public enum PaletteSelection {
    public static func moved(currentID: String?, by delta: Int, resultIDs: [String]) -> String? {
        guard !resultIDs.isEmpty else { return nil }
        guard let currentID, let current = resultIDs.firstIndex(of: currentID) else {
            return delta < 0 ? resultIDs.last : resultIDs.first
        }
        let index = (current + delta + resultIDs.count) % resultIDs.count
        return resultIDs[index]
    }

    public static func preserving(currentID: String?, resultIDs: [String]) -> String? {
        if let currentID, resultIDs.contains(currentID) { return currentID }
        return resultIDs.first
    }
}
