import Foundation

let delegate = TranscriptionEngineListenerDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
