#import "RecordAmrPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <EMVoiceConvert/EMVoiceConvert.h>
#import "amrFileCodec.h"

@interface RecordAmrPlugin () <AVAudioRecorderDelegate>
{
    NSError *_error;
    NSString *recordPath;
    FlutterResult _endResult;
}
@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) NSDictionary *recordSetting;
@property (nonatomic, strong) NSDate *startDate;

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
        if (error) {
            NSLog(@"error -- %@",error);
        }
        
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
        self.recorder = [[AVAudioRecorder alloc] initWithURL:wavUrl settings:self.recordSetting error:&error];
        if(error || !self.recorder) {
            self.recorder = nil;
            error = [NSError errorWithDomain:@"初始化录制失败" code:-1 userInfo:nil];
            break;
        }
        
        BOOL ret = [self.recorder prepareToRecord];
        if (ret) {
            self.startDate = [NSDate date];
            self.recorder.meteringEnabled = YES;
            self.recorder.delegate = self;
            ret = [self.recorder record];
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

- (void)_stopRecord
{
    _recorder.delegate = nil;
    _path = nil;
    if (_recorder.recording) {
        [_recorder stop];
    }
    _recorder = nil;
}


-(void)stopRecordWithCompletion:(FlutterResult)aCompletion
{
    _endResult = aCompletion;
    [self.recorder stop];
}

-(void)cancelRecord
{
    [self _stopRecord];
    _path = nil;
    self.startDate = nil;
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
    NSInteger timeLength = [[NSDate date] timeIntervalSinceDate:self.startDate];
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
        timeLength = 0;
    }
    self.recorder = nil;
    if (_endResult) {
        _endResult(@{@"path":amrFilePath, @"timeLength":@(timeLength)});
    }
    _endResult = nil;
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder
                                   error:(NSError *)error{
    [self _stopRecord];
    _endResult(@{@"path":@"", @"timeLength": @(0)});
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
