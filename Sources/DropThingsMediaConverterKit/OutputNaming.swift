import Foundation

/// Pure functions for building output URLs and resolving name conflicts. Has no
/// filesystem access, so it is fully testable. The pipeline owns the actual
/// writes; this only computes where a write should go.
public enum OutputNaming {
    /// Suggested output URL for `source` converted to `format`, inside
    /// `directory`. Keeps the original base name and swaps the extension. The
    /// returned URL may already exist; callers resolve that with
    /// `resolve(_:conflict:exists:)`.
    public static func proposedURL(
        for source: URL,
        format: MediaFormatID,
        in directory: URL
    ) -> URL {
        let base = source.deletingPathExtension().lastPathComponent
        // `formatting` collapses combining sequences and isolates control
        // chars; we additionally reject empty results so a hostile name like
        // ".hidden" cannot collapse into ".png" silently.
        let safeBase = sanitizeBase(base)
        let resolved = safeBase.isEmpty ? "Converted" : safeBase
        guard let ext = format.preferredExtension else {
            return directory.appendingPathComponent(resolved)
        }
        return directory.appendingPathComponent(resolved)
            .appendingPathExtension(ext)
    }

    /// Resolve a collision according to `policy`. `exists` is an injected
    /// predicate so this stays pure (no FileManager in the kit). Returns `nil`
    /// when the policy is `.fail` and the URL is taken.
    public static func resolve(
        _ url: URL,
        conflict: ConflictPolicy,
        exists: (URL) -> Bool
    ) -> URL? {
        if !exists(url) { return url }
        switch conflict {
        case .skip, .fail:
            return nil
        case .suffix:
            return firstAvailableSuffix(url, exists: exists)
        }
    }

    /// Appends " 2", " 3", ... before the extension until the predicate says
    /// the URL is free. Bounded at a high count to avoid an unbounded loop on
    /// pathological inputs.
    public static func firstAvailableSuffix(_ url: URL, exists: (URL) -> Bool) -> URL {
        let directory = url.deletingPathExtension()
        let base = directory.lastPathComponent
        let parent = directory.deletingLastPathComponent()
        let ext = url.pathExtension
        let maxAttempts = 1000
        for index in 2...maxAttempts {
            let candidateName = "\(base) \(index)"
            var candidate = parent.appendingPathComponent(candidateName)
            if !ext.isEmpty {
                candidate = candidate.appendingPathExtension(ext)
            }
            if !exists(candidate) { return candidate }
        }
        // Fall back to a UUID-suffixed name; should be unreachable in practice.
        var fallback = parent.appendingPathComponent("\(base) \(UUID().uuidString.prefix(8))")
        if !ext.isEmpty { fallback = fallback.appendingPathExtension(ext) }
        return fallback
    }

    /// Strips path separators, control characters, and a leading "." so a
    /// hostile or odd base name cannot escape the output directory or hide the
    /// file. Does not transliterate — non-ASCII display names are preserved.
    public static func sanitizeBase(_ name: String) -> String {
        // Drop path separators and NUL/control chars.
        var cleaned = String(name.unicodeScalars.filter { scalar in
            scalar.value != 0x0000
                && scalar != "\n"
                && scalar != "\r"
                && scalar != "/"
                && scalar != ":"
                && !(scalar.value < 0x20)
                && scalar != "\u{7F}"
        })
        // A leading dot would make the file invisible / collide with ".ext".
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        // Trim whitespace that could confuse suffix counting.
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
