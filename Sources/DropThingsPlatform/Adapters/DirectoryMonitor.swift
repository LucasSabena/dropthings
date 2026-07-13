import Foundation

/// Narrow wrapper around a directory vnode listener. Consumers rescan their
/// own domain after an event, which avoids leaking file-system details into UI.
@MainActor
public final class DirectoryMonitor {
    private let url: URL
    private let handler: @MainActor () -> Void
    private var descriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?

    public init(url: URL, handler: @escaping @MainActor () -> Void) {
        self.url = url
        self.handler = handler
    }

    public func start() {
        stop()
        descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in self?.handler() }
        source.setCancelHandler { [descriptor] in if descriptor >= 0 { close(descriptor) } }
        self.source = source
        source.resume()
    }

    public func stop() {
        source?.cancel()
        source = nil
        descriptor = -1
    }
}
