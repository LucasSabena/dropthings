#import "DTAudioRTProcessor.h"

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>

namespace {

static_assert(std::atomic<float>::is_always_lock_free, "Real-time gain atomics must be lock-free");
static_assert(std::atomic<uint64_t>::is_always_lock_free, "Real-time counters must be lock-free");

struct RTState {
    std::atomic<float> targetGain { 1.0F };
    std::atomic<float> currentGain { 1.0F };
    std::atomic<float> peak { 0.0F };
    std::atomic<uint64_t> overloads { 0 };
};

static float limitSample(float sample) noexcept {
    if (!std::isfinite(sample)) { return 0.0F; }
    constexpr float ceiling = 0.98F;
    constexpr float knee = ceiling * 0.9F;
    const float magnitude = std::fabs(sample);
    if (magnitude <= knee) { return sample; }
    constexpr float remaining = ceiling - knee;
    const float limited = knee + remaining * (1.0F - std::exp(-(magnitude - knee) / remaining));
    return std::copysign(std::min(ceiling, limited), sample);
}

static OSStatus render(
    AudioObjectID,
    const AudioTimeStamp *,
    const AudioBufferList *input,
    const AudioTimeStamp *,
    AudioBufferList *output,
    const AudioTimeStamp *,
    void *context
) noexcept {
    auto *state = static_cast<RTState *>(context);
    if (state == nullptr || output == nullptr) { return kAudioHardwareNoError; }

    for (UInt32 index = 0; index < output->mNumberBuffers; ++index) {
        auto &buffer = output->mBuffers[index];
        if (buffer.mData != nullptr) { std::memset(buffer.mData, 0, buffer.mDataByteSize); }
    }
    if (input == nullptr) { return kAudioHardwareNoError; }

    const float current = state->currentGain.load(std::memory_order_relaxed);
    float target = state->targetGain.load(std::memory_order_relaxed);
    if (!std::isfinite(target)) { target = 1.0F; }
    target = std::clamp(target, 0.0F, 1.0F);
    float peak = 0.0F;

    const UInt32 bufferCount = std::min(input->mNumberBuffers, output->mNumberBuffers);
    for (UInt32 bufferIndex = 0; bufferIndex < bufferCount; ++bufferIndex) {
        const auto &sourceBuffer = input->mBuffers[bufferIndex];
        auto &destinationBuffer = output->mBuffers[bufferIndex];
        if (sourceBuffer.mData == nullptr || destinationBuffer.mData == nullptr) { continue; }
        const UInt32 byteCount = std::min(sourceBuffer.mDataByteSize, destinationBuffer.mDataByteSize);
        const UInt32 sampleCount = byteCount / sizeof(float);
        if (sampleCount == 0) { continue; }

        const auto *source = static_cast<const float *>(sourceBuffer.mData);
        auto *destination = static_cast<float *>(destinationBuffer.mData);
        const UInt32 channelCount = std::max<UInt32>(1, sourceBuffer.mNumberChannels);
        const UInt32 frameCount = std::max<UInt32>(1, sampleCount / channelCount);
        const float step = (target - current) / static_cast<float>(frameCount);
        for (UInt32 sampleIndex = 0; sampleIndex < sampleCount; ++sampleIndex) {
            const UInt32 frameIndex = std::min(frameCount, sampleIndex / channelCount + 1);
            const float gain = current + step * static_cast<float>(frameIndex);
            const float processed = limitSample(source[sampleIndex] * gain);
            destination[sampleIndex] = processed;
            peak = std::max(peak, std::fabs(processed));
        }
    }

    state->currentGain.store(target, std::memory_order_relaxed);
    state->peak.store(peak, std::memory_order_relaxed);
    if (peak >= 0.98F) { state->overloads.fetch_add(1, std::memory_order_relaxed); }
    return kAudioHardwareNoError;
}

static NSError *makeError(OSStatus status, NSString *operation) {
    return [NSError errorWithDomain:@"app.dropthings.audio.rt"
                               code:status
                           userInfo:@{NSLocalizedDescriptionKey:
                                          [NSString stringWithFormat:@"%@ failed (OSStatus %d)", operation, status]}];
}

} // namespace

@implementation DTAudioRTProcessor {
    AudioObjectID _deviceID;
    AudioDeviceIOProcID _ioProcID;
    RTState *_state;
}

- (instancetype)initWithDeviceID:(AudioObjectID)deviceID {
    self = [super init];
    if (self) {
        _deviceID = deviceID;
        _ioProcID = nullptr;
        _state = new RTState();
    }
    return self;
}

- (void)dealloc {
    [self stop];
    delete _state;
}

- (BOOL)start:(NSError **)error {
    if (_ioProcID != nullptr) { return YES; }
    OSStatus status = AudioDeviceCreateIOProcID(_deviceID, render, _state, &_ioProcID);
    if (status != noErr) {
        _ioProcID = nullptr;
        if (error) { *error = makeError(status, @"Create audio callback"); }
        return NO;
    }
    status = AudioDeviceStart(_deviceID, _ioProcID);
    if (status != noErr) {
        AudioDeviceDestroyIOProcID(_deviceID, _ioProcID);
        _ioProcID = nullptr;
        if (error) { *error = makeError(status, @"Start audio callback"); }
        return NO;
    }
    return YES;
}

- (void)stop {
    if (_ioProcID == nullptr) { return; }
    AudioDeviceStop(_deviceID, _ioProcID);
    AudioDeviceDestroyIOProcID(_deviceID, _ioProcID);
    _ioProcID = nullptr;
}

- (void)setTargetGain:(float)gain {
    const float safe = std::isfinite(gain) ? std::clamp(gain, 0.0F, 1.0F) : 1.0F;
    _state->targetGain.store(safe, std::memory_order_release);
}

- (float)peakLevel {
    return _state->peak.exchange(0.0F, std::memory_order_relaxed);
}

- (uint64_t)overloadCount {
    return _state->overloads.load(std::memory_order_relaxed);
}

@end
