import AppKit
import Carbon.HIToolbox

/// Wraps Carbon's `RegisterEventHotKey` so a module can subscribe to a
/// system-wide keyboard shortcut without dragging Carbon's C API into the
/// module code. Carbon hotkeys work even when DropThings is not the focused
/// app, which is the whole point — they summon the shelf from anywhere.
///
/// Lifecycle is strict: call `register()` once and `unregister()` before the
/// owning object goes away. The deinit calls `unregister()` defensively so a
/// dangling listener never outlives the module.
public final class GlobalHotkey: @unchecked Sendable {
    public enum RegistrationError: Error, Equatable {
        case installHandlerFailed(Int32)
        case registerFailed(Int32)
    }

    /// Key + modifier + id pair. The `id` is what `Carbon` returns inside
    /// the event so we can match it against the right `GlobalHotkey` when
    /// multiple modules each register their own.
    public struct Definition: Equatable, Sendable, Codable, Hashable {
        public let keyCode: UInt32
        public let modifiers: UInt32
        public let id: UInt32

        public init(keyCode: UInt32, modifiers: UInt32, id: UInt32) {
            self.keyCode = keyCode
            self.modifiers = modifiers
            self.id = id
        }
    }

    public static let defaultShelfHotkey = Definition(
        keyCode: UInt32(kVK_ANSI_S),
        modifiers: UInt32(cmdKey | optionKey),
        id: 1
    )

    public static let defaultColorPickerHotkey = Definition(
        keyCode: UInt32(kVK_ANSI_C),
        modifiers: UInt32(cmdKey | optionKey),
        id: 2
    )

    public static let defaultScreenshotHotkey = Definition(
        keyCode: UInt32(kVK_ANSI_4),
        modifiers: UInt32(cmdKey | shiftKey),
        id: 3
    )

    private let definition: Definition
    private let onFire: @MainActor () -> Void
    private var handlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private let lock = NSLock()

    public init(definition: Definition, onFire: @escaping @MainActor () -> Void) {
        self.definition = definition
        self.onFire = onFire
    }

    deinit {
        unregister()
    }

    public func register() throws {
        lock.lock()
        defer { lock.unlock() }
        guard hotKeyRef == nil else { return }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let userData else { return noErr }
                let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                let size = MemoryLayout<EventHotKeyID>.size
                let paramStatus = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    size,
                    nil,
                    &hotKeyID
                )
                if paramStatus == noErr && hotKeyID.id == hotkey.definition.id {
                    DispatchQueue.main.async {
                        hotkey.onFire()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &handlerRef
        )

        guard installStatus == noErr else {
            throw RegistrationError.installHandlerFailed(installStatus)
        }

        let hotKeyID = EventHotKeyID(
            signature: OSType(0x44525448), // 'DRTH' — arbitrary unique fourcc
            id: definition.id
        )
        let registerStatus = RegisterEventHotKey(
            definition.keyCode,
            definition.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            RemoveEventHandler(handlerRef)
            handlerRef = nil
            throw RegistrationError.registerFailed(registerStatus)
        }
    }

    public func unregister() {
        lock.lock()
        defer { lock.unlock() }
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    public var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return hotKeyRef != nil
    }
}

public extension GlobalHotkey.Definition {
    /// Human-readable shortcut like `⌃⌥⌘C`. Falls back to "Key 47" for
    /// keycodes we have not catalogued.
    var displayString: String {
        let mods = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        var parts: [String] = []
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        parts.append(Self.keyCodeName(for: Int(keyCode)))
        return parts.joined()
    }

    /// `true` when at least one standard modifier is set. We refuse to
    /// record a shortcut with no modifier so a stray key press can never
    /// accidentally trigger a module.
    var hasModifier: Bool {
        let mods = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        let required: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        return !mods.intersection(required).isEmpty
    }

    private static func keyCodeName(for keyCode: Int) -> String {
        switch keyCode {
        case Int(kVK_ANSI_A): return "A"
        case Int(kVK_ANSI_B): return "B"
        case Int(kVK_ANSI_C): return "C"
        case Int(kVK_ANSI_D): return "D"
        case Int(kVK_ANSI_E): return "E"
        case Int(kVK_ANSI_F): return "F"
        case Int(kVK_ANSI_G): return "G"
        case Int(kVK_ANSI_H): return "H"
        case Int(kVK_ANSI_I): return "I"
        case Int(kVK_ANSI_J): return "J"
        case Int(kVK_ANSI_K): return "K"
        case Int(kVK_ANSI_L): return "L"
        case Int(kVK_ANSI_M): return "M"
        case Int(kVK_ANSI_N): return "N"
        case Int(kVK_ANSI_O): return "O"
        case Int(kVK_ANSI_P): return "P"
        case Int(kVK_ANSI_Q): return "Q"
        case Int(kVK_ANSI_R): return "R"
        case Int(kVK_ANSI_S): return "S"
        case Int(kVK_ANSI_T): return "T"
        case Int(kVK_ANSI_U): return "U"
        case Int(kVK_ANSI_V): return "V"
        case Int(kVK_ANSI_W): return "W"
        case Int(kVK_ANSI_X): return "X"
        case Int(kVK_ANSI_Y): return "Y"
        case Int(kVK_ANSI_Z): return "Z"
        case Int(kVK_ANSI_0): return "0"
        case Int(kVK_ANSI_1): return "1"
        case Int(kVK_ANSI_2): return "2"
        case Int(kVK_ANSI_3): return "3"
        case Int(kVK_ANSI_4): return "4"
        case Int(kVK_ANSI_5): return "5"
        case Int(kVK_ANSI_6): return "6"
        case Int(kVK_ANSI_7): return "7"
        case Int(kVK_ANSI_8): return "8"
        case Int(kVK_ANSI_9): return "9"
        case Int(kVK_Space): return "Space"
        case Int(kVK_Delete): return "⌫"
        case Int(kVK_Tab): return "⇥"
        case Int(kVK_Return): return "↩"
        case Int(kVK_Escape): return "⎋"
        case Int(kVK_LeftArrow): return "←"
        case Int(kVK_RightArrow): return "→"
        case Int(kVK_UpArrow): return "↑"
        case Int(kVK_DownArrow): return "↓"
        case Int(kVK_F1): return "F1"
        case Int(kVK_F2): return "F2"
        case Int(kVK_F3): return "F3"
        case Int(kVK_F4): return "F4"
        case Int(kVK_F5): return "F5"
        case Int(kVK_F6): return "F6"
        case Int(kVK_F7): return "F7"
        case Int(kVK_F8): return "F8"
        case Int(kVK_F9): return "F9"
        case Int(kVK_F10): return "F10"
        case Int(kVK_F11): return "F11"
        case Int(kVK_F12): return "F12"
        default: return "Key \(keyCode)"
        }
    }
}
