#import "RecordAmrPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <EMVoiceConvert/EMVoiceConvert.h>

@interface RecordAmrPlugin ()
@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@end

@implementation RecordAmrPlugin


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"record_amr"
                                     binaryMessenger:[registrar messenger]];
    RecordAmrPlugin* instance = [[RecordAmrPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call
                  result:(FlutterResult)result {
    
    NSLog(@"call.method --- %@",call.method);
    
    if ([@"startVoiceRecord" isEqualToString:call.method])
    {
        [self startVoiceRecord:call.arguments result:result];
    } else if ([@"stopVoiceRecord" isEqualToString:call.method])
    {
        [self stopVoiceRecord:call.arguments result:result];
    } else if ([@"cancelVoiceRecord" isEqualToString:call.method])
    {
        [self cancelVoiceRecord:call.arguments result:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)startVoiceRecord:(NSDictionary *)callInfo result:(FlutterResult)result {
    NSString *recordPath = [self.path stringByAppendingFormat:@"/%.0f", [[NSDate date] timeIntervalSince1970] * 1000];
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDuckOthers error:&error];
    if (!error){
        [[AVAudioSession sharedInstance] setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    }
    
    if (error) {
        error = [NSError errorWithDomain:@"AVAudioSession SetCategory失败" code:-1 userInfo:nil];
        break;
    }
    NSLog(@"start record");
    result(@(YES));
}

- (void)stopVoiceRecord:(NSDictionary *)callInfo result:(FlutterResult)result {
    NSLog(@"stop record");
    result(@"我是路径");
}

- (void)cancelVoiceRecord:(NSDictionary *)callInfo result:(FlutterResult)result {
    result(@(YES));
}


- (NSString *)path
{
    if (!_path) {
        _path =  [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        _path = [_path stringByAppendingPathComponent:@"EMRecord"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:_path]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:_path withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return _path;
}
@end
