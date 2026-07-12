import AppKit
import SwiftUI

/// One logical item in an AppKit dragging session. A drag with multiple
/// values must use multiple `NSDraggingItem`s; registering several objects on
/// one `NSItemProvider` still represents only one pasteboard item.
public struct NativeDragItem {
    public let pasteboardWriter: any NSPasteboardWriting
    public let previewImage: NSImage?

    public init(
        pasteboardWriter: any NSPasteboardWriting,
        previewImage: NSImage? = nil
    ) {
        self.pasteboardWriter = pasteboardWriter
        self.previewImage = previewImage
    }
}

public extension View {
    /// Makes a SwiftUI surface start a native AppKit drag containing one
    /// pasteboard item per value returned by `items`.
    ///
    /// The adapter is intentionally narrow: SwiftUI owns the row/card UI and
    /// selection, while AppKit owns only the multi-item dragging session.
    func nativeMultiItemDragSource(
        items: @escaping () -> [NativeDragItem]
    ) -> some View {
        background(NativeDragSourceAnchor(items: items))
    }
}

private struct NativeDragSourceAnchor: NSViewRepresentable {
    let items: () -> [NativeDragItem]

    func makeNSView(context: Context) -> NativeDragSourceView {
        NativeDragSourceView(items: items)
    }

    func updateNSView(_ nsView: NativeDragSourceView, context: Context) {
        nsView.items = items
    }
}

/// Transparent anchor behind a SwiftUI row/card. A local event monitor lets
/// it observe a drag without stealing ordinary clicks, buttons, or context
/// menus from the SwiftUI content in front of it.
private final class NativeDragSourceView: NSView, NSDraggingSource {
    var items: () -> [NativeDragItem]

    private var eventMonitor: Any?
    private var mouseDownLocation: NSPoint?
    private var suppressMouseUp = false

    init(items: @escaping () -> [NativeDragItem]) {
        self.items = items
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("NativeDragSourceView is built in code only.")
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reconcileEventMonitor()
    }

    private func reconcileEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        guard window != nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard event.window === window else { return event }
        let location = convert(event.locationInWindow, from: nil)

        switch event.type {
        case .leftMouseDown:
            mouseDownLocation = bounds.contains(location) ? location : nil
            suppressMouseUp = false
            return event

        case .leftMouseDragged:
            guard let start = mouseDownLocation,
                  hypot(location.x - start.x, location.y - start.y) >= 4 else {
                return event
            }
            mouseDownLocation = nil
            suppressMouseUp = startDragging(with: event, at: location)
            return suppressMouseUp ? nil : event

        case .leftMouseUp:
            mouseDownLocation = nil
            if suppressMouseUp {
                suppressMouseUp = false
                return nil
            }
            return event

        default:
            return event
        }
    }

    @discardableResult
    private func startDragging(with event: NSEvent, at location: NSPoint) -> Bool {
        let payload = items()
        guard !payload.isEmpty else { return false }

        let draggingItems = payload.enumerated().map { index, item in
            let draggingItem = NSDraggingItem(pasteboardWriter: item.pasteboardWriter)
            let offset = CGFloat(min(index, 6)) * 3
            let size = NSSize(width: 44, height: 44)
            let origin = NSPoint(
                x: location.x - size.width / 2 + offset,
                y: location.y - size.height / 2 - offset
            )
            draggingItem.setDraggingFrame(
                NSRect(origin: origin, size: size),
                contents: item.previewImage ?? Self.fallbackPreview
            )
            return draggingItem
        }

        beginDraggingSession(with: draggingItems, event: event, source: self)
        return true
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        false
    }

    private static let fallbackPreview = NSImage(
        systemSymbolName: "doc.on.doc",
        accessibilityDescription: "Dragged items"
    )
}
