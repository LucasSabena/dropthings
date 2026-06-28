import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Floating, focus-light panel for the File Shelf. macOS-level behavior lives
/// here; the SwiftUI list and the module business logic stay out of this file
/// so this remains a thin adapter per `docs/architecture.md` (Platform).
public final class ShelfPanel: NSPanel {
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
            styleMask: [.titled, .resizable, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        title = "File Shelf"
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false
        minSize = NSSize(width: 280, height: 180)
    }
}

/// Content view that hosts the SwiftUI shelf list and accepts drops via
/// AppKit's `NSDraggingDestination`. SwiftUI's `.onDrop` works but does not
/// expose the `NSPasteboard` the same way, which makes it harder to share the
/// `PasteboardItemReader` between tests and the panel.
public final class ShelfContentView: NSView {
    public var onDrop: ((NSPasteboard) -> Void)?

    private let hosting: NSHostingView<AnyView>

    public init(rootView: AnyView) {
        self.hosting = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        addSubview(hosting)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        registerForDraggedTypes([
            NSPasteboard.PasteboardType(UTType.fileURL.identifier),
            NSPasteboard.PasteboardType(UTType.url.identifier),
            NSPasteboard.PasteboardType(UTType.plainText.identifier),
            .string
        ])
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("ShelfContentView is built in code only.")
    }

    public override func layout() {
        super.layout()
        hosting.frame = bounds
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pb = sender.draggingPasteboard
        if pb.canReadObject(forClasses: [NSURL.self], options: nil) {
            return .copy
        }
        if pb.types?.contains(.string) == true {
            return .copy
        }
        return []
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDrop?(sender.draggingPasteboard)
        return true
    }
}
