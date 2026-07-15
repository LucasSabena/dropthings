import CoreAudio
import Foundation

public struct SystemAudioOutputState: Equatable, Sendable {
    public let deviceUID: String
    public let volume: Double?
    public let isMuted: Bool
    public let canSetVolume: Bool
    public let canSetMute: Bool

    public init(
        deviceUID: String,
        volume: Double?,
        isMuted: Bool,
        canSetVolume: Bool,
        canSetMute: Bool
    ) {
        self.deviceUID = deviceUID
        self.volume = volume
        self.isMuted = isMuted
        self.canSetVolume = canSetVolume
        self.canSetMute = canSetMute
    }
}

public enum SystemAudioOutputError: LocalizedError, Equatable {
    case deviceUnavailable
    case volumeUnavailable
    case operationFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .deviceUnavailable:
            return "The selected audio output is no longer available."
        case .volumeUnavailable:
            return "This output does not expose software volume control."
        case .operationFailed(let status):
            return "Core Audio could not apply the change (\(status))."
        }
    }
}

/// Narrow host-side adapter for the system default output and its hardware
/// volume. Per-app taps remain isolated in the XPC engine.
public protocol SystemAudioOutputControlling: AnyObject {
    func state(forDeviceUID uid: String) throws -> SystemAudioOutputState
    func setDefaultOutput(deviceUID uid: String) throws
    func setVolume(_ volume: Double, forDeviceUID uid: String) throws
    func setMuted(_ muted: Bool, forDeviceUID uid: String) throws
}

public final class CoreAudioSystemOutputController: SystemAudioOutputControlling {
    public init() {}

    public func state(forDeviceUID uid: String) throws -> SystemAudioOutputState {
        let device = try deviceID(forUID: uid)
        let volumeAddresses = scalarAddresses(for: device)
        let muteAddresses = booleanAddresses(for: device, selector: kAudioDevicePropertyMute)
        let volumes = volumeAddresses.compactMap { try? readFloat32(object: device, address: $0) }
        let mutes = muteAddresses.compactMap { try? readUInt32(object: device, address: $0) }
        return SystemAudioOutputState(
            deviceUID: uid,
            volume: volumes.isEmpty ? nil : Double(volumes.reduce(0, +) / Float32(volumes.count)),
            isMuted: mutes.contains(where: { $0 != 0 }),
            canSetVolume: volumeAddresses.contains { isSettable(object: device, address: $0) },
            canSetMute: muteAddresses.contains { isSettable(object: device, address: $0) }
        )
    }

    public func setDefaultOutput(deviceUID uid: String) throws {
        let device = try deviceID(forUID: uid)
        try setDevice(device, selector: kAudioHardwarePropertyDefaultOutputDevice)
        // Alert and interface sounds follow the same choice when the device is
        // eligible. Some virtual devices reject this secondary property; the
        // primary output change remains valid in that case.
        try? setDevice(device, selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
    }

    public func setVolume(_ volume: Double, forDeviceUID uid: String) throws {
        let device = try deviceID(forUID: uid)
        let safe = Float32(max(0, min(1, volume)))
        let addresses = scalarAddresses(for: device).filter { isSettable(object: device, address: $0) }
        guard !addresses.isEmpty else { throw SystemAudioOutputError.volumeUnavailable }
        for address in addresses {
            var value = safe
            try setFloat32(&value, object: device, address: address)
        }
    }

    public func setMuted(_ muted: Bool, forDeviceUID uid: String) throws {
        let device = try deviceID(forUID: uid)
        let addresses = booleanAddresses(for: device, selector: kAudioDevicePropertyMute)
            .filter { isSettable(object: device, address: $0) }
        guard !addresses.isEmpty else { throw SystemAudioOutputError.volumeUnavailable }
        for address in addresses {
            var value: UInt32 = muted ? 1 : 0
            try setUInt32(&value, object: device, address: address)
        }
    }

    private func deviceID(forUID uid: String) throws -> AudioDeviceID {
        for device in try deviceIDs() where readUID(for: device) == uid && outputChannelCount(device) > 0 {
            return device
        }
        throw SystemAudioOutputError.deviceUnavailable
    }

    private func deviceIDs() throws -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size))
        var values = Array(repeating: AudioDeviceID(0), count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &values))
        return values
    }

    private func readUID(for device: AudioDeviceID) -> String? {
        var address = outputAddress(selector: kAudioDevicePropertyDeviceUID)
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, pointer)
        }
        return status == noErr ? value as String : nil
    }

    private func outputChannelCount(_ device: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr,
              size >= MemoryLayout<AudioBufferList>.size else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, raw) == noErr else { return 0 }
        return UnsafeMutableAudioBufferListPointer(raw.bindMemory(to: AudioBufferList.self, capacity: 1))
            .reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private func scalarAddresses(for device: AudioDeviceID) -> [AudioObjectPropertyAddress] {
        propertyAddresses(for: device, selector: kAudioDevicePropertyVolumeScalar)
    }

    private func booleanAddresses(
        for device: AudioDeviceID,
        selector: AudioObjectPropertySelector
    ) -> [AudioObjectPropertyAddress] {
        propertyAddresses(for: device, selector: selector)
    }

    private func propertyAddresses(
        for device: AudioDeviceID,
        selector: AudioObjectPropertySelector
    ) -> [AudioObjectPropertyAddress] {
        let candidates = (0...8).map { element in
            AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: AudioObjectPropertyElement(element)
            )
        }
        let available = candidates.filter { candidate in
            var address = candidate
            return AudioObjectHasProperty(device, &address)
        }
        if let master = available.first(where: { $0.mElement == kAudioObjectPropertyElementMain }) {
            return [master]
        }
        return available
    }

    private func outputAddress(selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func setDevice(
        _ device: AudioDeviceID,
        selector: AudioObjectPropertySelector
    ) throws {
        let address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = UInt32(device)
        try setUInt32(&value, object: AudioObjectID(kAudioObjectSystemObject), address: address)
    }

    private func readFloat32(
        object: AudioObjectID,
        address: AudioObjectPropertyAddress
    ) throws -> Float32 {
        var address = address
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value))
        return value
    }

    private func readUInt32(
        object: AudioObjectID,
        address: AudioObjectPropertyAddress
    ) throws -> UInt32 {
        var address = address
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value))
        return value
    }

    private func isSettable(
        object: AudioObjectID,
        address: AudioObjectPropertyAddress
    ) -> Bool {
        var address = address
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(object, &address, &settable) == noErr && settable.boolValue
    }

    private func setFloat32(
        _ value: inout Float32,
        object: AudioObjectID,
        address: AudioObjectPropertyAddress
    ) throws {
        var address = address
        try check(AudioObjectSetPropertyData(
            object,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &value
        ))
    }

    private func setUInt32(
        _ value: inout UInt32,
        object: AudioObjectID,
        address: AudioObjectPropertyAddress
    ) throws {
        var address = address
        try check(AudioObjectSetPropertyData(
            object,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &value
        ))
    }

    private func check(_ status: OSStatus) throws {
        guard status == noErr else { throw SystemAudioOutputError.operationFailed(status) }
    }
}
