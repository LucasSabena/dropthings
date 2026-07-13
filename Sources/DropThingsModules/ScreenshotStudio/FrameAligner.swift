import CoreGraphics

public struct FrameAlignment: Sendable, Equatable {
    public let overlap: Int
    public let confidence: Double
    public init(overlap: Int, confidence: Double) { self.overlap = overlap; self.confidence = confidence }
}

/// Pure, conservative row-overlap scorer for scrolling capture. It does not
/// infer offsets from scroll-wheel deltas; a candidate succeeds only when
/// image pixels support it.
public enum FrameAligner {
    public static func align(previous: CGImage, next: CGImage, minimumOverlap: Int = 24, maximumOverlap: Int? = nil) -> FrameAlignment? {
        guard previous.width == next.width, previous.height > minimumOverlap, next.height > minimumOverlap else { return nil }
        let max = min(maximumOverlap ?? min(previous.height, next.height) - 1, min(previous.height, next.height) - 1)
        guard max >= minimumOverlap, let first = rgba(previous), let second = rgba(next) else { return nil }
        guard hasTexture(first, width: previous.width, height: previous.height), hasTexture(second, width: next.width, height: next.height) else { return nil }
        var best: FrameAlignment?
        for overlap in stride(from: max, through: minimumOverlap, by: -1) {
            let score = similarity(first, second, width: previous.width, previousHeight: previous.height, nextHeight: next.height, overlap: overlap)
            let candidate = FrameAlignment(overlap: overlap, confidence: score)
            if best == nil || candidate.confidence > best!.confidence { best = candidate }
        }
        guard let best, best.confidence >= 0.985 else { return nil }
        return best
    }

    public static func stitch(_ frames: [CGImage], minimumConfidence: Double = 0.985) -> (image: CGImage, partial: Bool)? {
        guard let first = frames.first else { return nil }
        guard var pixels = rgba(first) else { return nil }
        var accepted: [(CGImage, Int)] = [(first, 0)]
        var partial = false
        for frame in frames.dropFirst() {
            guard let alignment = align(previous: accepted.last!.0, next: frame), alignment.confidence >= minimumConfidence else { partial = true; break }
            accepted.append((frame, alignment.overlap))
        }
        var height = first.height
        for entry in accepted.dropFirst() {
            guard let next = rgba(entry.0) else { return nil }
            let start = entry.1 * first.width * 4
            pixels.append(contentsOf: next[start...])
            height += entry.0.height - entry.1
        }
        guard let context = CGContext(data: &pixels, width: first.width, height: height, bitsPerComponent: 8, bytesPerRow: first.width * 4, space: first.colorSpace ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let image = context.makeImage() else { return nil }
        return (image, partial)
    }

    private static func rgba(_ image: CGImage) -> [UInt8]? {
        let count = image.width * image.height * 4; var bytes = [UInt8](repeating: 0, count: count)
        guard let context = CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height)); return bytes
    }
    private static func similarity(_ previous: [UInt8], _ next: [UInt8], width: Int, previousHeight: Int, nextHeight: Int, overlap: Int) -> Double {
        var error = 0.0; let samples = overlap * width
        guard samples > 0 else { return 0 }
        for row in 0..<overlap {
            let previousRow = previousHeight - overlap + row
            for column in 0..<width {
                let left = (previousRow * width + column) * 4; let right = (row * width + column) * 4
                let red = abs(Int(previous[left]) - Int(next[right]))
                let green = abs(Int(previous[left + 1]) - Int(next[right + 1]))
                let blue = abs(Int(previous[left + 2]) - Int(next[right + 2]))
                error += Double(red + green + blue)
            }
        }
        return max(0, 1 - error / Double(samples * 3 * 255))
    }
    private static func hasTexture(_ bytes: [UInt8], width: Int, height: Int) -> Bool {
        guard width > 1, height > 1 else { return false }
        var variation = 0
        for row in stride(from: 1, to: height, by: max(1, height / 32)) {
            for column in 1..<width { variation += abs(Int(bytes[(row * width + column) * 4]) - Int(bytes[(row * width + column - 1) * 4])) }
            variation += abs(Int(bytes[(row * width) * 4]) - Int(bytes[((row - 1) * width) * 4]))
        }
        return variation > width
    }
}
