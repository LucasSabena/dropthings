import Foundation

let delegate = AudioControlEngineListenerDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
