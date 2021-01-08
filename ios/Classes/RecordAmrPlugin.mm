#import "RecordAmrPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <EMVoiceConvert/EMVoiceConvert.h>
#import "amrFileCodec.h"

@interface RecordAmrPlugin () <AVAudioRecorderDelegate>
{
    NSError *_error;
    NSString *recordPath;
    FlutterResult _endResult;
    NSTimer *_levelTimer;
    NSDictionary *_recordSetting;
    NSDate *_startDate;
}
@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) FlutterMethodChannel* channel;

@end
    
@implementation RecordAmrPlugin


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"record_amr"
                                     binaryMessenger:[registrar messenger]];
    RecordAmrPlugin* instance = [[RecordAmrPlugin alloc] init];
    instance.channel = channel;
    [registrar addMethodCallDelegate:instance channel:channel];
}


- (void)handleMethodCall:(FlutterMethodCall*)call
                  result:(FlutterResult)result {
    
    if ([@"startVoiceRecord" isEqualToString:call.method])
    {
        [self startVoiceRecord:call.arguments result:result];
    }
    else if ([@"stopVoiceRecord" isEqualToString:call.method])
    {
        [self stopVoiceRecord:call.arguments result:result];
    }
    else if ([@"cancelVoiceRecord" isEqualToString:call.method])
    {
        [self cancelVoiceRecord:call.arguments result:result];
    }
    else if ([@"playAmrFile" isEqualToString:call.method])
    {
        [self playAmr:call.arguments result:result];
    }
    else if ([@"stopPlayAmrFile" isEqualToString:call.method])
    {
        [self stopPlayAmrFile:call.arguments result:result];
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}


- (void)playAmr:(NSDictionary *)callInfo result:(FlutterResult)result
{
    NSString *filePath = callInfo[@"path"];
    NSLog(@"%@", filePath);
    result(@(YES));
}

- (void)stopPlayAmrFile:(NSDictionary *)callInfo result:(FlutterResult)result
{
    NSString *filePath = callInfo[@"path"];
    NSLog(@"%@", filePath);
    result(@(YES));
}


- (void)startVoiceRecord:(NSDictionary *)callInfo result:(FlutterResult)result {
    
    if (self.recorder && self.recorder.isRecording) {
        NSLog(@"开始失败，目前正在录制");
        result(@NO);
        return;
    }
    
    NSError *error;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDuckOthers error:&error];
    if (!error){
        [[AVAudioSession sharedInstance] setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    }
    
    if (error) {
        error = [NSError errorWithDomain:@"AVAudioSession SetCategory失败" code:-1 userInfo:nil];
        NSLog(@"开始失败，设备初始化错误");
        result(@NO);
        return;
    }
    
    recordPath = [self.path stringByAppendingFormat:@"/%.0f", [[NSDate date] timeIntervalSince1970] * 1000];
    [self startRecordWithPath:recordPath
                   completion:^(NSError *error)
    {
        result(@(error == nil));
    }];
}

- (void)stopVoiceRecord:(NSDictionary *)callInfo result:(FlutterResult)result {
    [self stopRecordWithCompletion:result];
}

- (void)cancelVoiceRecord:(NSDictionary *)callInfo result:(FlutterResult)result {
    [self cancelRecord];
    result(@(YES));
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _recordSetting = @{
            AVSampleRateKey:@(8000.0),
            AVFormatIDKey:@(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey:@(16),
            AVNumberOfChannelsKey:@(1),
            AVEncoderAudioQualityKey:@(AVAudioQualityHigh)
        };
    }
    
    return self;
}



- (void)dealloc
{
    [self _stopRecord];
}



- (void)startRecordWithPath:(NSString *)aPath
                 completion:(void(^)(NSError *error))aCompletion
{
    NSError *error = nil;
    do {

        NSString *wavPath = [[aPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"wav"];
        NSURL *wavUrl = [[NSURL alloc] initFileURLWithPath:wavPath];
        self.recorder = [[AVAudioRecorder alloc] initWithURL:wavUrl settings:_recordSetting error:&error];
        if(error || !self.recorder) {
            self.recorder = nil;
            error = [NSError errorWithDomain:@"初始化录制失败" code:-1 userInfo:nil];
            break;
        }
        
        BOOL ret = [self.recorder prepareToRecord];
        if (ret) {
            _startDate = [NSDate date];
            self.recorder.meteringEnabled = YES;
            self.recorder.delegate = self;
            ret = [self.recorder record];
            _levelTimer = [NSTimer scheduledTimerWithTimeInterval: 0.3 target: self
                                                         selector: @selector(levelTimerCallback:)
                                                         userInfo: nil
                                                          repeats: YES];
        }
        
        if (!ret) {
            [self _stopRecord];
            error = [NSError errorWithDomain:@"准备录制工作失败" code:-1 userInfo:nil];
        }
        
    } while (0);
    
    if (aCompletion) {
        aCompletion(error);
    }
}

#pragma mark - Private

- (void)levelTimerCallback:(NSTimer *)timer {
    if (!_recorder) {
        return;
    }
    [_recorder updateMeters];
    
    float   level;                // The linear 0.0 .. 1.0 value we need.
    float   minDecibels = -60.0f; // use -80db Or use -60dB, which I measured in a silent room.
    float   decibels    = [_recorder averagePowerForChannel:0];
    
    if (decibels < minDecibels)
    {
        level = 0.0f;
    }
    else if (decibels >= 0.0f)
    {
        level = 1.0f;
    }
    else
    {
        float   root            = 5.0f; //modified level from 2.0 to 5.0 is neast to real test
        float   minAmp          = powf(10.0f, 0.05f * minDecibels);
        float   inverseAmpRange = 1.0f / (1.0f - minAmp);
        float   amp             = powf(10.0f, 0.05f * decibels);
        float   adjAmp          = (amp - minAmp) * inverseAmpRange;
        
        level = powf(adjAmp, 1.0f / root);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.channel invokeMethod:@"volume" arguments:@(level)];
    });
}

- (void)_stopRecord
{
    _recorder.delegate = nil;
    _path = nil;
    if (_recorder.recording) {
        [_recorder stop];
    }
    if (_levelTimer) {
        [_levelTimer invalidate];
    }
    _levelTimer = nil;
    _recorder = nil;
    _path = nil;
    _startDate = nil;
}


-(void)stopRecordWithCompletion:(FlutterResult)aCompletion
{
    _endResult = aCompletion;
    [self.recorder stop];
}

-(void)cancelRecord
{
    [self _stopRecord];
}


#pragma mark - Private

+ (int)wavPath:(NSString *)aWavPath toAmrPath:(NSString*)aAmrPath
{
    
    if (EM_EncodeWAVEFileToAMRFile([aWavPath cStringUsingEncoding:NSASCIIStringEncoding], [aAmrPath cStringUsingEncoding:NSASCIIStringEncoding], 1, 16))
        return 0;   // success
    
    return 1;   // failed
}

- (BOOL)_convertWAV:(NSString *)aWavPath toAMR:(NSString *)aAmrPath
{
    BOOL ret = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:aAmrPath]) {
        ret = YES;
    } else if ([fileManager fileExistsAtPath:aWavPath]) {
        [RecordAmrPlugin wavPath:aWavPath toAmrPath:aAmrPath];
        if ([fileManager fileExistsAtPath:aAmrPath]) {
            ret = YES;
        }
    }
    
    return ret;
}

#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder
                           successfully:(BOOL)flag
{
    NSInteger duration = [[NSDate date] timeIntervalSinceDate:_startDate];
    NSString *recordPath = [[self.recorder url] path];
    if (!flag) {
        recordPath = nil;
    }
    // Convert wav to amr
    NSString *amrFilePath = [[recordPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"amr"];
    BOOL ret = [self _convertWAV:recordPath toAMR:amrFilePath];
    if (ret) {
        // Remove the wav
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:recordPath error:nil];

        amrFilePath = amrFilePath;
    } else {
        recordPath = nil;
        duration = 0;
    }
    self.recorder = nil;
    if (_endResult) {
        _endResult(@{@"path":amrFilePath, @"duration":@(duration)});
    }
    _endResult = nil;
    [self _stopRecord];
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder
                                   error:(NSError *)error{
    [self _stopRecord];
    _endResult(@{@"path":@"", @"duration": @(0), @"error": error.domain});
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
