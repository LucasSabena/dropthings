import AppKit
import CoreAudio
import DropThingsAudioControlKit

struct RunningAudioProcess {
    /// An application can own several Core Audio processes (notably Electron
    /// renderers). A single tap must include every process that is currently
    /// producing output for that application.
    let objectIDs: [AudioObjectID]
    let identity: AudioAppIdentity
    let isRunningOutput: Bool
}

struct CoreAudioCatalog {
    func processes() -> [RunningAudioProcess] {
        let rawProcesses = objectIDs(selector: kAudioHardwarePropertyProcessObjectList).compactMap { objectID -> RunningAudioProcess? in
            guard let pid: pid_t = scalar(objectID, selector: kAudioProcessPropertyPID) else { return nil }
            let running = (scalar(objectID, selector: kAudioProcessPropertyIsRunningOutput) as UInt32?) == 1
            let application = NSRunningApplication(processIdentifier: pid)
            let identity = appIdentity(
                for: application,
                reportedBundleID: string(objectID, selector: kAudioProcessPropertyBundleID)
            )
            return RunningAudioProcess(
                objectIDs: running ? [objectID] : [],
                identity: identity,
                isRunningOutput: running
            )
        }

        return Dictionary(grouping: rawProcesses, by: { $0.identity.stableID })
            .compactMap { _, processes in
                guard let first = processes.first else { return nil }
                let outputObjectIDs = processes.flatMap(\.objectIDs)
                return RunningAudioProcess(
                    objectIDs: outputObjectIDs,
                    identity: first.identity,
                    isRunningOutput: !outputObjectIDs.isEmpty
                )
            }
    }

    func devices() -> [AudioDeviceIdentity] {
        let defaultID: AudioObjectID = scalar(AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDefaultOutputDevice) ?? kAudioObjectUnknown
        return objectIDs(selector: kAudioHardwarePropertyDevices).compactMap { objectID in
            guard let uid = string(objectID, selector: kAudioDevicePropertyDeviceUID),
                  let name = string(objectID, selector: kAudioObjectPropertyName) else { return nil }
            let transportCode: UInt32 = scalar(objectID, selector: kAudioDevicePropertyTransportType) ?? 0
            let sampleRate: Float64 = scalar(objectID, selector: kAudioDevicePropertyNominalSampleRate) ?? 0
            let alive: UInt32 = scalar(objectID, selector: kAudioDevicePropertyDeviceIsAlive) ?? 0
            var volumeAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            return AudioDeviceIdentity(
                uid: uid,
                name: name,
                transport: transportName(transportCode),
                sampleRate: sampleRate,
                isAvailable: alive == 1,
                hasVolumeControl: AudioObjectHasProperty(objectID, &volumeAddress),
                isDefault: objectID == defaultID
            )
        }
    }

    func audioObjectID(forDeviceUID uid: String) -> AudioObjectID? {
        objectIDs(selector: kAudioHardwarePropertyDevices).first {
            string($0, selector: kAudioDevicePropertyDeviceUID) == uid
        }
    }

    func defaultOutputID() -> AudioObjectID? {
        let value: AudioObjectID? = scalar(AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDefaultOutputDevice)
        return value == kAudioObjectUnknown ? nil : value
    }

    func defaultOutputUID() -> String? {
        defaultOutputID().flatMap { string($0, selector: kAudioDevicePropertyDeviceUID) }
    }

    /// A row may outlive the Core Audio process object while its application is
    /// open. This allows the UI to stay stable across stream teardown/recreate
    /// cycles without treating an idle app as active audio.
    func isApplicationRunning(_ identity: AudioAppIdentity) -> Bool {
        guard let bundleID = identity.bundleID else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    func cleanupOwnedAggregateDevices() {
        for objectID in objectIDs(selector: kAudioHardwarePropertyDevices) {
            guard let uid = string(objectID, selector: kAudioDevicePropertyDeviceUID),
                  let name = string(objectID, selector: kAudioObjectPropertyName),
                  OwnedAudioResource.isOwned(uid: uid),
                  name == "DropThings Private Audio Path" else { continue }
            AudioHardwareDestroyAggregateDevice(objectID)
        }
    }

    private func objectIDs(selector: AudioObjectPropertySelector) -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var values = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.stride)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &values) == noErr else { return [] }
        return values
    }

    private func scalar<T>(_ objectID: AudioObjectID, selector: AudioObjectPropertySelector) -> T? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        memset(pointer, 0, MemoryLayout<T>.size)
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer) == noErr else { return nil }
        return pointer.pointee
    }

    private func string(_ objectID: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer)
        }
        guard status == noErr else { return nil }
        return value as String
    }

    private func transportName(_ code: UInt32) -> String {
        switch code {
        case kAudioDeviceTransportTypeBuiltIn: return "Built-in"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "Bluetooth"
        case kAudioDeviceTransportTypeUSB: return "USB"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: return "Display"
        case kAudioDeviceTransportTypeAirPlay: return "AirPlay"
        case kAudioDeviceTransportTypeAggregate: return "Aggregate"
        default: return "Audio device"
        }
    }

    private func appIdentity(
        for application: NSRunningApplication?,
        reportedBundleID: String?
    ) -> AudioAppIdentity {
        let containerBundle = application.flatMap(containingApplicationBundle)
        let bundleID = containerBundle?.bundleIdentifier
            ?? application?.bundleIdentifier
            ?? reportedBundleID?.nonEmpty
        let fallback = application?.executableURL?.path ?? "unidentified-audio-process"
        let displayName = (containerBundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (containerBundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? application?.localizedName
            ?? bundleID
            ?? URL(fileURLWithPath: fallback).lastPathComponent
        return AudioAppIdentity(bundleID: bundleID, processFallback: fallback, displayName: displayName)
    }

    /// Maps a helper nested inside an app bundle back to its owning app. This
    /// uses only public bundle paths and keeps Electron helpers such as Discord
    /// Renderer from appearing as unrelated applications.
    private func containingApplicationBundle(_ application: NSRunningApplication) -> Bundle? {
        guard let bundleURL = application.bundleURL else { return nil }
        let components = bundleURL.pathComponents
        guard let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) else {
            return Bundle(url: bundleURL)
        }
        return Bundle(url: URL(fileURLWithPath: "/").appendingPathComponent(components[1...appIndex].joined(separator: "/")))
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
