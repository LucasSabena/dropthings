import AppKit
import CoreGraphics

/// Geometry is always expressed in source-image pixels. Views may zoom or pan,
/// but neither operation can change exported pixels.
public struct ScreenshotPoint: Codable, Hashable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public init(_ point: CGPoint) { x = point.x; y = point.y }
    public var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

public struct ScreenshotRect: Codable, Hashable, Sendable {
    public var x: CGFloat; public var y: CGFloat; public var width: CGFloat; public var height: CGFloat
    public init(_ rect: CGRect) { x = rect.origin.x; y = rect.origin.y; width = rect.width; height = rect.height }
    public var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height).standardized }
}

public struct ScreenshotColor: Codable, Hashable, Sendable {
    public var red: CGFloat; public var green: CGFloat; public var blue: CGFloat; public var alpha: CGFloat
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) { self.red = red; self.green = green; self.blue = blue; self.alpha = alpha }
    public var cgColor: CGColor { CGColor(red: red, green: green, blue: blue, alpha: alpha) }
    public static let red = ScreenshotColor(red: 1, green: 0.23, blue: 0.19)
    public static let yellow = ScreenshotColor(red: 1, green: 0.82, blue: 0.1, alpha: 0.45)
}

public enum ScreenshotAnnotationKind: String, Codable, CaseIterable, Sendable {
    case arrow, line, rectangle, ellipse, freehand, text, highlight, marker, blur, pixelate
}

public struct ScreenshotAnnotation: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var kind: ScreenshotAnnotationKind
    public var bounds: ScreenshotRect
    public var points: [ScreenshotPoint]
    public var text: String
    public var color: ScreenshotColor
    public var fill: ScreenshotColor?
    public var lineWidth: CGFloat
    public var fontSize: CGFloat
    public var markerNumber: Int?

    public init(id: UUID = UUID(), kind: ScreenshotAnnotationKind, bounds: CGRect, points: [CGPoint] = [], text: String = "", color: ScreenshotColor = .red, fill: ScreenshotColor? = nil, lineWidth: CGFloat = 3, fontSize: CGFloat = 18, markerNumber: Int? = nil) {
        self.id = id; self.kind = kind; self.bounds = ScreenshotRect(bounds); self.points = points.map(ScreenshotPoint.init); self.text = text; self.color = color; self.fill = fill; self.lineWidth = lineWidth; self.fontSize = fontSize; self.markerNumber = markerNumber
    }
}

public struct ScreenshotDocumentSnapshot: Sendable {
    fileprivate let annotations: [ScreenshotAnnotation]
    fileprivate let crop: ScreenshotRect?
}

@MainActor
public final class ScreenshotDocument: ObservableObject {
    public let source: CGImage
    public let scale: CGFloat
    @Published public private(set) var annotations: [ScreenshotAnnotation]
    @Published public private(set) var crop: ScreenshotRect?
    @Published public private(set) var selectedID: UUID?
    @Published public private(set) var isDirty = false

    private var undoStack: [ScreenshotDocumentSnapshot] = []
    private var redoStack: [ScreenshotDocumentSnapshot] = []

    public init(source: CGImage, scale: CGFloat = 1, annotations: [ScreenshotAnnotation] = [], crop: CGRect? = nil) {
        self.source = source; self.scale = scale; self.annotations = annotations; self.crop = crop.map(ScreenshotRect.init)
    }

    public var sourceBounds: CGRect { CGRect(x: 0, y: 0, width: source.width, height: source.height) }
    public var effectiveCrop: CGRect { crop?.cgRect.intersection(sourceBounds) ?? sourceBounds }
    public var canUndo: Bool { !undoStack.isEmpty }; public var canRedo: Bool { !redoStack.isEmpty }

    public func add(_ annotation: ScreenshotAnnotation) { mutate { annotations.append(annotation); selectedID = annotation.id } }
    public func replace(_ annotation: ScreenshotAnnotation) { mutate { guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }; annotations[index] = annotation } }
    public func deleteSelected() { mutate { annotations.removeAll { $0.id == selectedID }; selectedID = nil } }
    public func select(_ id: UUID?) { selectedID = id }
    public func setCrop(_ rect: CGRect?) { mutate { crop = rect.map { ScreenshotRect($0.intersection(sourceBounds)) } } }
    public func undo() { guard let previous = undoStack.popLast() else { return }; redoStack.append(snapshot()); restore(previous) }
    public func redo() { guard let next = redoStack.popLast() else { return }; undoStack.append(snapshot()); restore(next) }
    public func markSaved() { isDirty = false }

    private func mutate(_ block: () -> Void) { undoStack.append(snapshot()); redoStack.removeAll(); block(); isDirty = true }
    private func snapshot() -> ScreenshotDocumentSnapshot { ScreenshotDocumentSnapshot(annotations: annotations, crop: crop) }
    private func restore(_ snapshot: ScreenshotDocumentSnapshot) { annotations = snapshot.annotations; crop = snapshot.crop; selectedID = nil; isDirty = true }
}
