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
            guard let identity = appIdentity(
                for: application,
                reportedBundleID: string(objectID, selector: kAudioProcessPropertyBundleID)
            ) else { return nil }
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
        let devices = objectIDs(selector: kAudioHardwarePropertyDevices).compactMap { objectID -> AudioDeviceIdentity? in
            guard let uid = string(objectID, selector: kAudioDevicePropertyDeviceUID),
                  let name = string(objectID, selector: kAudioObjectPropertyName),
                  outputChannelCount(objectID) > 0,
                  !OwnedAudioResource.isOwned(uid: uid) else { return nil }
            let transportCode: UInt32 = scalar(objectID, selector: kAudioDevicePropertyTransportType) ?? 0
            let sampleRate: Float64 = scalar(objectID, selector: kAudioDevicePropertyNominalSampleRate) ?? 0
            let alive: UInt32 = scalar(objectID, selector: kAudioDevicePropertyDeviceIsAlive) ?? 0
            return AudioDeviceIdentity(
                uid: uid,
                name: name,
                transport: transportName(transportCode),
                sampleRate: sampleRate,
                isAvailable: alive == 1,
                hasVolumeControl: hasOutputVolumeControl(objectID),
                isDefault: objectID == defaultID
            )
        }
        return Dictionary(grouping: devices, by: \AudioDeviceIdentity.uid)
            .values
            .compactMap(\.first)
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
    ) -> AudioAppIdentity? {
        let containerBundle = application.flatMap(containingApplicationBundle)
        let installedBundle = reportedBundleID?.nonEmpty
            .flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            .flatMap(containingApplicationBundle)

        // A Core Audio process commonly belongs to an Electron/Chromium helper.
        // Resolve that helper to the outer app, then prefer the running app that
        // owns the bundle. This keeps Canva and Edge as a single, recognizable
        // mixer entry rather than exposing their internal process names.
        let owningBundle = containerBundle ?? installedBundle
        let ownerApplication = owningBundle.flatMap(runningUserFacingApplication)

        // Only surface identities that resolve to a real application bundle.
        // Core Audio also reports helpers, agents and daemons; showing their
        // executable names makes the mixer noisy and misleading.
        guard let owningBundle else {
            return nil
        }

        // A prohibited process without a regular/accessory app owner is a
        // background helper (for example PowerChime), not a mixer app.
        guard ownerApplication != nil || application?.activationPolicy != .prohibited else {
            return nil
        }

        let bundleID = owningBundle.bundleIdentifier
            ?? ownerApplication?.bundleIdentifier
            ?? application?.bundleIdentifier
        let fallback = application?.executableURL?.path
            ?? owningBundle.bundleURL.path
            ?? "unidentified-audio-process"
        let displayName = (owningBundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (owningBundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? ownerApplication?.localizedName
            ?? application?.localizedName
            ?? bundleID
            ?? URL(fileURLWithPath: fallback).lastPathComponent
        return AudioAppIdentity(bundleID: bundleID, processFallback: fallback, displayName: displayName)
    }

    /// Maps a helper nested inside an app bundle back to its owning app. This
    /// uses only public bundle paths and keeps Electron helpers such as Discord
    /// Renderer from appearing as unrelated applications.
    private func containingApplicationBundle(_ application: NSRunningApplication) -> Bundle? {
        guard let url = application.bundleURL ?? application.executableURL else { return nil }
        return containingApplicationBundle(at: url)
    }

    private func containingApplicationBundle(at url: URL) -> Bundle? {
        let components = url.standardizedFileURL.pathComponents
        guard let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        let relativePath = components.dropFirst().prefix(appIndex).joined(separator: "/")
        return Bundle(url: URL(fileURLWithPath: "/").appendingPathComponent(relativePath))
    }

    private func runningUserFacingApplication(owning bundle: Bundle) -> NSRunningApplication? {
        let bundleURL = bundle.bundleURL.standardizedFileURL
        return NSWorkspace.shared.runningApplications.first { candidate in
            guard candidate.activationPolicy != .prohibited,
                  let candidateBundle = containingApplicationBundle(candidate) else { return false }
            return candidateBundle.bundleURL.standardizedFileURL == bundleURL
        }
    }

    private func outputChannelCount(_ device: AudioObjectID) -> Int {
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
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        return UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private func hasOutputVolumeControl(_ device: AudioObjectID) -> Bool {
        (0...8).contains { element in
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: AudioObjectPropertyElement(element)
            )
            return AudioObjectHasProperty(device, &address)
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
