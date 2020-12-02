//
//  BZQRecordPlayViewController.m
//  AudioUnitManager
//
//  Created by bzq on 2020/11/30.
//

#import "BZQRecordPlayViewController.h"
#import <AVFoundation/AVFoundation.h>

/*
 一个AudioUnit（音频单元）有两个元素，分别是Element0和Element1，因为0和1分别像Output和Input的首字母，
 所以我们定义INPUT_BUS和OUTPUT_BUS分别代表两个元素。当然在代码中你直接用1和0也是完全可以的
 除了两个元素（Element），一个AU还分为两个Scope（范围），分别是Input Scope和Out Scope。
 这个两个范围分别指每个元素的输入和输出区域。
 然后在这两个范围下面，还有一个Global Scope，即包括了两个输入和输出的范围。
 详情可见官方文档“Audio Unit Hosting Fundamentals”，图1-2.

 这里要注意区分输入和输出元素，以及每个元素的输出和输出范围。实际上，可以简单理解为有四个区域，
 其中，Element0的Output Scope是连接硬件扬声器（或者听筒，或者耳机，反正就是音频硬件）的，
 Element1的Input Scope是连接硬件麦克风的（或者耳机麦克风，或者外置的收音器），
 这两个区域因为直接连接硬件，我们无法更改其属性，设置了也没用。官方文档中图1-3，橙色是我们能更改的，蓝色的不能。
 但是需要注意的是，我们需要配置打开Element1的Input Scope的能力，才能录音。
 */
#define INPUT_BUS 1
#define OUTPUT_BUS 0

#define CONST_BUFFER_SIZE 5000

@interface BZQRecordPlayViewController ()
//业务相关
@property (strong, nonatomic) UIButton *recordButton;
@property (strong, nonatomic) UIButton *playButton;
@property (assign, nonatomic) BOOL recording;
@property (assign, nonatomic) BOOL playing;
@property (strong, nonatomic) NSInputStream *inputStream;
@property (strong, nonatomic) NSOutputStream *outoutStream;

//音频相关
@property (assign, nonatomic) AudioUnit recordAudioUnit;
@property (assign, nonatomic) AudioUnit playAudioUnit;
@end

@implementation BZQRecordPlayViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"录制和播放PCM";
    self.view.backgroundColor = UIColor.whiteColor;


    self.recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:self.recordButton];
    self.recordButton.frame = CGRectMake(20, 200, 200, 50);
    [self.recordButton setTitle:@"录制PCM音频" forState:UIControlStateNormal];
    [self.recordButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [self.recordButton addTarget:self
                          action:@selector(recordButtonClick)
                forControlEvents:UIControlEventTouchUpInside];

    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:self.playButton];
    self.playButton.frame = CGRectMake(20, 300, 200, 50);
    [self.playButton setTitle:@"播放录制的音频" forState:UIControlStateNormal];
    [self.playButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [self.playButton addTarget:self
                        action:@selector(playButtonClick)
              forControlEvents:UIControlEventTouchUpInside];

    //设置AVAudioSession，保证能播放和录制
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                     withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                                           error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    self.recording = NO;
    self.playing = NO;

    [self setupAudioUnit];
}

#pragma mark - AudioUnit相关配置
//简称ASBD，就是PCM格式音频的描述文件，可以设置采样率，声道数量等
+ (AudioStreamBasicDescription)audioPCMFormat {
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = 16000; //采样率
    audioFormat.mFormatID = kAudioFormatLinearPCM; //音频格式

    //详细描述了音频数据的数字格式，整数还是浮点数，大端还是小端
    audioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;

    //下面就是设置声音采集时的一些值
    //官方解释：满足下面这个公式时，上面的mFormatFlags会隐式设置为kAudioFormatFlagIsPacked
    //((mBitsPerSample / 8) * mChannelsPerFrame) == mBytesPerFrame
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mBytesPerFrame = 2;
    audioFormat.mChannelsPerFrame = 1;//单声道，如果是2就是立体声。这里的数量决定了AudioBufferList的mBuffers长度是1还是2。
    audioFormat.mBitsPerChannel = 16;

    return audioFormat;
}

- (void)setupAudioUnit {
    OSStatus status = noErr;

    //官方文档有比较详细的说明：https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitHostingGuide_iOS/ConstructingAudioUnitApps/ConstructingAudioUnitApps.html#//apple_ref/doc/uid/TP40009492-CH16-SW1

    //通过音频组件描述数据创建AudioUnit
    //如果想创建多个AudioUnit串联对音频数据进行多重处理（混音，回声消除等），需要用AUGraph
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    //有些Demo中这里用kAudioUnitSubType_VoiceProcessingIO，这个是用来处理回声消除的，声音会从手机出来，而不是耳机
    //这里只有默认的录音和播放，用kAudioUnitSubType_RemoteIO就可以了
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple; //iOS都用这个，Mac上不太一样
    //下面这两个除非你知道具体是干嘛的，否则用0就行了
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    AudioComponent component = AudioComponentFindNext(NULL, &audioDesc);
    //播放和录音用相同的描述文件即可，下面两行代码执行完两个音频单元就创建好了
    AudioComponentInstanceNew(component, &_recordAudioUnit);
    AudioComponentInstanceNew(component, &_playAudioUnit);

    //设置录音相关属性，即INPUT_BUS相关
    //录音的格式，注意这里设置的是INPUT_BUS的kAudioUnitScope_Output
    AudioStreamBasicDescription pcmFormat = [self.class audioPCMFormat];
    AudioUnitSetProperty(self.recordAudioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &pcmFormat,
                         sizeof(pcmFormat));

    //打开录音流功能，否则无法录音
    //但是播放能力是默认打开的，所以不需要设置OUTPUT_BUS的kAudioUnitScope_Output
    UInt32 enableRecord = 1;
    AudioUnitSetProperty(self.recordAudioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         INPUT_BUS,
                         &enableRecord,
                         sizeof(enableRecord));

    //录音的回调方法，INPUT_BUS收音之后拿到的音频数据，会通过这个静态方法回调给我们
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = RecordCallback;
    recordCallback.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(self.recordAudioUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Output,
                                  INPUT_BUS,
                                  &recordCallback,
                                  sizeof(recordCallback));

    //设置播放相关属性，即OUTPUT_BUS
    //播放的格式，即我们处理音频之后要把这个格式的数据通过回调传出去给硬件来播放
    AudioUnitSetProperty(self.playAudioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &pcmFormat,
                         sizeof(pcmFormat));

    //播放的回调方法，需要把被播放的数据通过这个方法的回调传出去
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(self.playAudioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Global,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));

    //初始化，注意，这里只是初始化，还没开始播放
    status = AudioUnitInitialize(self.recordAudioUnit);
    NSLog(@"XAFTFAudioUnit AudioUnitInitialize record %u", status);
    status = AudioUnitInitialize(self.playAudioUnit);
    NSLog(@"XAFTFAudioUnit AudioUnitInitialize play %u", status);
}

#pragma mark - callback function
static OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData) {
    BZQRecordPlayViewController *vc = (__bridge BZQRecordPlayViewController*)inRefCon;
    //用来缓存录音数据数据结构
    AudioBufferList *bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers = 1; //声道数，如果是立体声，这里应该是2
    //下面是这个结构要缓存的音频的大小，这个值需要根据采样率，声道等共同设置，如果不知道多少就大一些也无所谓
    bufferList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    bufferList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);

    //录音渲染完成，把声音数据已经放到bufferList里面了
    OSStatus status = AudioUnitRender(vc.recordAudioUnit,
                                      ioActionFlags,
                                      inTimeStamp,
                                      inBusNumber,
                                      inNumberFrames,
                                      bufferList);
    if (status != noErr) {
        NSLog(@"RecordCallback AudioUnitRender error %d", status);
    }
    Byte *bufferData = bufferList->mBuffers[0].mData;
    UInt32 bufferSize = bufferList->mBuffers[0].mDataByteSize;
    NSLog(@"RecordCallback bufferList = %u", bufferSize);

    //录音完成，可以对音频数据进行处理了，保存下来或者计算录音的分贝数等等
    //如果你需要计算录音时的音量，显示录音动画，这里就可以通过bufferList->mBuffers[0].mData计算得出

    //[BZQRecordPlayViewController writePCMData:bufferData size:bufferSize];
    [vc.outoutStream write:bufferData maxLength:bufferSize];

    //下面就是释放处理完录音的音频之后，释放缓存的内容
    if (bufferList != NULL) {
        if (bufferList->mBuffers[0].mData) {
            free(bufferList->mBuffers[0].mData);
            bufferList->mBuffers[0].mData = NULL;
        }
        free(bufferList);
        bufferList = NULL;
    }
    return status;
}

static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    BZQRecordPlayViewController *vc = (__bridge BZQRecordPlayViewController *)inRefCon;

    //把要播放的声音放到输出的数组里面
    ioData->mBuffers[0].mDataByteSize = (UInt32)[vc.inputStream read:ioData->mBuffers[0].mData
                                                           maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];
    NSLog(@"PlayCallback bufferList = %u", ioData->mBuffers[0].mDataByteSize);
    //判断是否播放完了
    if (ioData->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [vc stopPlay];
        });
    }
    return noErr;
}

#pragma mark - 音频数据处理
+ (NSString *)filePath {
    return [NSTemporaryDirectory() stringByAppendingString:@"/record.pcm"];
}

#pragma mark - Private
- (void)startRecord {
    self.title = @"录音中";
    [self.recordButton setTitle:@"暂停录音" forState:UIControlStateNormal];
    AudioOutputUnitStart(self.recordAudioUnit);
    self.recording = YES;
    self.outoutStream = [NSOutputStream outputStreamToFileAtPath:[self.class filePath] append:NO];
    [self.outoutStream open];
}
- (void)stopRecord {
    self.title = @"录音结束";
    [self.recordButton setTitle:@"录制PCM音频" forState:UIControlStateNormal];
    AudioOutputUnitStop(self.recordAudioUnit);
    self.recording = NO;
    [self.outoutStream close];
}

- (void)startPlay {
    self.title = @"播放录制的音频";
    [self.playButton setTitle:@"暂停播放" forState:UIControlStateNormal];
    AudioOutputUnitStart(self.playAudioUnit);
    self.playing = YES;
    self.inputStream = [NSInputStream inputStreamWithFileAtPath:[self.class filePath]];
    [self.inputStream open];
}

- (void)stopPlay {
    self.title = @"停止播放";
    [self.playButton setTitle:@"播放录制的音频" forState:UIControlStateNormal];
    AudioOutputUnitStop(self.playAudioUnit);
    self.playing = NO;
    [self.inputStream close];
}

- (void)recordButtonClick {
    if (self.recording) {
        [self stopRecord];
    } else {
        if (self.playing) {
            [self stopPlay];
        }
        [self startRecord];
    }
}

- (void)playButtonClick {
    if (self.playing) {
        [self stopPlay];
    } else {
        if (self.recording) {
            [self stopRecord];
        }
        [self startPlay];
    }
}

@end
