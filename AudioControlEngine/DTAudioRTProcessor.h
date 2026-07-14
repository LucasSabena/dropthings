#import <CoreAudio/CoreAudio.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Owns one IOProc. Its callback touches only preallocated C++ state and audio
/// buffers; Objective-C is used only for setup, parameter publication, and
/// teardown off the real-time thread.
@interface DTAudioRTProcessor : NSObject

- (instancetype)initWithDeviceID:(AudioObjectID)deviceID;
- (BOOL)start:(NSError * _Nullable * _Nullable)error;
- (void)stop;
- (void)setTargetGain:(float)gain;
- (float)peakLevel;
- (uint64_t)overloadCount;

@end

NS_ASSUME_NONNULL_END
