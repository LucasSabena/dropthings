#import "DTMediaRemoteBridge.h"

typedef void (^DTMediaRemoteInfoCompletion)(NSDictionary * _Nullable information);
typedef void (^DTMediaRemotePIDCompletion)(int pid);
typedef void (^DTMediaRemotePlayingCompletion)(BOOL isPlaying);
typedef void (*DTMediaRemoteGetInfo)(dispatch_queue_t queue, DTMediaRemoteInfoCompletion completion);
typedef void (*DTMediaRemoteGetPID)(dispatch_queue_t queue, DTMediaRemotePIDCompletion completion);
typedef void (*DTMediaRemoteGetPlaying)(dispatch_queue_t queue, DTMediaRemotePlayingCompletion completion);
typedef BOOL (*DTMediaRemoteSendCommand)(NSInteger command, id _Nullable userInfo);

@implementation DTMediaRemoteBridge {
    dispatch_queue_t _queue;
    DTMediaRemoteGetInfo _getInfo;
    DTMediaRemoteGetPID _getPID;
    DTMediaRemoteGetPlaying _getPlaying;
    DTMediaRemoteSendCommand _sendCommand;
}

- (instancetype)init {
    self = [super init];
    if (!self) { return nil; }

    _queue = dispatch_queue_create("app.dropthings.media-remote", DISPATCH_QUEUE_SERIAL);
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/MediaRemote.framework"];
    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, url);
    if (!bundle) { return self; }
    CFBundleLoadExecutable(bundle);
    _getInfo = (DTMediaRemoteGetInfo)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));
    _getPID = (DTMediaRemoteGetPID)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingApplicationPID"));
    _getPlaying = (DTMediaRemoteGetPlaying)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingApplicationIsPlaying"));
    _sendCommand = (DTMediaRemoteSendCommand)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSendCommand"));
    CFRelease(bundle);
    return self;
}

- (BOOL)isAvailable {
    return _getInfo != NULL && _getPID != NULL && _getPlaying != NULL && _sendCommand != NULL;
}

- (NSDictionary<NSString *, id> *)snapshotWithTimeout:(NSTimeInterval)timeout {
    if (!self.available) { return nil; }

    dispatch_group_t group = dispatch_group_create();
    NSMutableDictionary<NSString *, id> *result = [NSMutableDictionary dictionary];

    dispatch_group_enter(group);
    _getPID(_queue, ^(int pid) {
        if (pid > 0) { result[@"pid"] = @(pid); }
        dispatch_group_leave(group);
    });

    dispatch_group_enter(group);
    _getPlaying(_queue, ^(BOOL isPlaying) {
        result[@"isPlaying"] = @(isPlaying);
        dispatch_group_leave(group);
    });

    dispatch_group_enter(group);
    _getInfo(_queue, ^(NSDictionary *information) {
        if (information) {
            id title = information[@"kMRMediaRemoteNowPlayingInfoTitle"];
            id artist = information[@"kMRMediaRemoteNowPlayingInfoArtist"];
            id album = information[@"kMRMediaRemoteNowPlayingInfoAlbum"];
            if ([title isKindOfClass:NSString.class]) { result[@"title"] = title; }
            if ([artist isKindOfClass:NSString.class]) { result[@"artist"] = artist; }
            if ([album isKindOfClass:NSString.class]) { result[@"album"] = album; }
        }
        dispatch_group_leave(group);
    });

    const int64_t nanoseconds = (int64_t)(MAX(0.1, timeout) * NSEC_PER_SEC);
    if (dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, nanoseconds)) != 0) {
        return nil;
    }
    return result[@"title"] ? result.copy : nil;
}

- (BOOL)sendCommand:(NSInteger)command error:(NSError **)error {
    if (!self.available) {
        if (error) {
            *error = [NSError errorWithDomain:@"app.dropthings.media-remote" code:1 userInfo:@{NSLocalizedDescriptionKey: @"System media controls are unavailable on this version of macOS."}];
        }
        return NO;
    }
    if (!_sendCommand(command, nil)) {
        if (error) {
            *error = [NSError errorWithDomain:@"app.dropthings.media-remote" code:2 userInfo:@{NSLocalizedDescriptionKey: @"The active media app did not accept that command."}];
        }
        return NO;
    }
    return YES;
}

@end
