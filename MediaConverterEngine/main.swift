import Foundation

// Mirrors AudioControlEngine/main.swift. The delegate is retained by the
// listener's delegate property; resume() keeps the service alive.
let delegate = MediaConverterEngineListenerDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
