import CoreAudio
import DropThingsAudioControlKit

enum AudioPipelineError: LocalizedError {
    case coreAudio(operation: String, status: OSStatus)
    case missingTapUID
    case unsupportedStreamFormat

    var errorDescription: String? {
        switch self {
        case .coreAudio(let operation, let status): return "\(operation) failed (OSStatus \(status))."
        case .missingTapUID: return "Core Audio did not return a tap identity."
        case .unsupportedStreamFormat: return "The selected output does not expose a safe Float32 processing format."
        }
    }
}

final class ProcessAudioPipeline {
    let appIdentity: AudioAppIdentity
    let deviceUID: String

    private(set) var tapID = AudioObjectID(kAudioObjectUnknown)
    private(set) var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var processor: DTAudioRTProcessor?

    init(
        process: RunningAudioProcess,
        deviceUID: String,
        sessionID: UUID,
        initialGain: Float
    ) throws {
        appIdentity = process.identity
        self.deviceUID = deviceUID
        do {
            let description = CATapDescription(processes: process.objectIDs, deviceUID: deviceUID, stream: 0)
            description.name = "DropThings · \(process.identity.displayName)"
            description.isPrivate = true
            description.muteBehavior = .mutedWhenTapped

            var createdTap = AudioObjectID(kAudioObjectUnknown)
            try check(AudioHardwareCreateProcessTap(description, &createdTap), operation: "Create process tap")
            tapID = createdTap

            let tapUID = try readTapUID(createdTap)
            let resourceStem = "\(OwnedAudioResource.uidPrefix)\(sessionID.uuidString.lowercased()).\(UUID().uuidString.lowercased())"
            let aggregateDescription: [String: Any] = [
                kAudioAggregateDeviceUIDKey: resourceStem + ".aggregate",
                kAudioAggregateDeviceNameKey: "DropThings Private Audio Path",
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceMainSubDeviceKey: deviceUID,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: deviceUID]],
                kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: tapUID]]
            ]
            var createdAggregate = AudioObjectID(kAudioObjectUnknown)
            try check(
                AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &createdAggregate),
                operation: "Create private aggregate device"
            )
            aggregateID = createdAggregate
            guard isFloat32Device(createdAggregate) else { throw AudioPipelineError.unsupportedStreamFormat }

            let processor = DTAudioRTProcessor(deviceID: createdAggregate)
            processor.setTargetGain(initialGain)
            try processor.start()
            self.processor = processor
        } catch {
            stop()
            throw error
        }
    }

    deinit { stop() }

    func setGain(_ gain: Float) { processor?.setTargetGain(gain) }
    var peakLevel: Float { processor?.peakLevel() ?? 0 }
    var overloadCount: UInt64 { processor?.overloadCount() ?? 0 }

    func stop() {
        processor?.stop()
        processor = nil
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = kAudioObjectUnknown
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = kAudioObjectUnknown
        }
    }

    private func readTapUID(_ tapID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &uid) { pointer in
            AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, pointer)
        }
        try check(status, operation: "Read tap identity")
        let value = uid as String
        guard !value.isEmpty else { throw AudioPipelineError.missingTapUID }
        return value
    }

    private func isFloat32Device(_ deviceID: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &format) == noErr else { return false }
        return format.mFormatID == kAudioFormatLinearPCM
            && format.mFormatFlags & kAudioFormatFlagIsFloat != 0
            && format.mBitsPerChannel == 32
    }

    private func check(_ status: OSStatus, operation: String) throws {
        guard status == noErr else { throw AudioPipelineError.coreAudio(operation: operation, status: status) }
    }
}
