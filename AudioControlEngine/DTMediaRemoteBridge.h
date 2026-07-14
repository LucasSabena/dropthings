#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Compatibility wrapper around macOS's private MediaRemote framework. The
/// helper owns this boundary so a framework failure cannot affect the host UI
/// or the real-time audio path.
@interface DTMediaRemoteBridge : NSObject

@property(nonatomic, readonly, getter=isAvailable) BOOL available;

/// Returns lightweight Now Playing fields, or nil when no session is exposed.
- (nullable NSDictionary<NSString *, id> *)snapshotWithTimeout:(NSTimeInterval)timeout;

/// Sends a MediaRemote transport command. Command values intentionally mirror
/// the narrowly supported `MediaTransportCommand` enum in the shared protocol.
- (BOOL)sendCommand:(NSInteger)command error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
