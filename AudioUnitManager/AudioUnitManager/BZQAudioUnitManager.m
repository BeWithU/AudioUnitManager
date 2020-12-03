//
//  BZQAudioUnitManager.m
//  AudioUnitManager
//
//  Created by bzq on 2020/12/3.
//

#import "BZQAudioUnitManager.h"
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioConverter.h>

const static NSInteger INPUT_BUS = 1;
const static NSInteger OUTPUT_BUS = 0;

const static NSInteger CONST_BUFFER_SIZE = 5000;

@interface BZQAudioUnitManager()

@property (copy, nonatomic) void (^recordBlock)(NSData *, CGFloat);
//音频相关，录音和播放单元可以是一个，即同时录音和播放，但是比较难控制暂停和开始，所以这里用两个
@property (assign, nonatomic) AudioUnit recordAudioUnit;
@property (assign, nonatomic) AudioUnit playAudioUnit;

@end

@implementation BZQAudioUnitManager

+ (instancetype)sharedManager {
    static BZQAudioUnitManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [BZQAudioUnitManager new];
        [manager setup];
    });
    return manager;
}

- (void)setup {
    
}

#pragma mark - Private
#pragma mark - AudioUnit相关配置
//简称ASBD，就是PCM格式音频的描述文件，可以设置采样率，声道数量等
+ (AudioStreamBasicDescription)audioPCMFormat {
    AudioStreamBasicDescription audioFormat;
    //采样率，每秒钟抽取声音样本次数。根据奈奎斯特采样理论，为了保证声音不失真，采样频率应该在40kHz左右
    audioFormat.mSampleRate = 44100;
    audioFormat.mFormatID = kAudioFormatLinearPCM; //音频格式

    //详细描述了音频数据的数字格式，整数还是浮点数，大端还是小端
    //注意，如果是双声道，这里一定要设置kAudioFormatFlagIsNonInterleaved，否则初始化AudioUnit会出现错误 1718449215
    //kAudioFormatFlagIsNonInterleaved，非交错模式，即首先记录的是一个周期内所有帧的左声道样本，再记录所有右声道样本。
    //对应的认为交错模式，数据以连续帧的方式存放，即首先记录帧1的左声道样本和右声道样本，再开始帧2的记录。
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;

    //下面就是设置声音采集时的一些值
    //比如采样率为44.1kHZ，采样精度为16位的双声道，可以算出比特率（bps）是44100*16*2bps，每秒的音频数据是固定的44100*16*2/8字节。
    //官方解释：满足下面这个公式时，上面的mFormatFlags会隐式设置为kAudioFormatFlagIsPacked
    //((mBitsPerSample / 8) * mChannelsPerFrame) == mBytesPerFrame
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mBytesPerFrame = 2;
    audioFormat.mChannelsPerFrame = 1;//1是单声道，2就是立体声。这里的数量决定了AudioBufferList的mBuffers长度是1还是2。
    audioFormat.mBitsPerChannel = 16;//采样位数，数字越大，分辨率越高。16位可以记录65536个数，一般来说够用了。

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
    //播放的格式设置为立体声
    AudioStreamBasicDescription outputFormat = pcmFormat;
    outputFormat.mChannelsPerFrame = 2;
    status = AudioUnitSetProperty(self.playAudioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &outputFormat,
                         sizeof(outputFormat));

    //播放的回调方法，需要把被播放的数据通过这个方法的回调传出去
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(self.playAudioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));

    //初始化，注意，这里只是初始化，还没开始播放
    //这里初始化出现错误，请检查audioPCMFormat，outputFormat等格式是否有设置错误的
    //比如设置了双声道，但是没有设置kAudioFormatFlagIsNonInterleaved
    status = AudioUnitInitialize(self.recordAudioUnit);
    NSLog(@"AudioUnitInitialize record %d", status);
    status = AudioUnitInitialize(self.playAudioUnit);
    NSLog(@"AudioUnitInitialize play %d", status);
}

#pragma mark - callback function
static OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData) {
    BZQAudioUnitManager *manager = (__bridge BZQAudioUnitManager*)inRefCon;
    //用来缓存录音数据数据结构
    AudioBufferList *bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers = 1; //声道数，如果是录制立体声，这里应该是2
    //下面是这个结构要缓存的音频的大小，这个值需要根据采样率，声道等共同设置，如果不知道多少就大一些也无所谓
    bufferList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    bufferList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);

    //录音渲染完成，把声音数据已经放到bufferList里面了
    OSStatus status = AudioUnitRender(manager.recordAudioUnit,
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
    BZQAudioUnitManager *manager = (__bridge BZQAudioUnitManager *)inRefCon;

#pragma mark - 立体声设置
    //立体声需要分别设置mBuffers[0]和mBuffers[1]，注意即使想单耳出声也不能不设置另外一个，否则会有杂音和错误
    //不想某个声道出声，长度正常设置，只需要把对应的mBuffers.mData清空为0就可以了

    //Byte *buffer = malloc(CONST_BUFFER_SIZE);

    return noErr;
}

#pragma mark - Public
- (void)recordWithBlock:(void (^)(NSData *pcmData, CGFloat vol))block {

}

- (void)stopRecord {

}

- (void)play {

}

- (void)addPCMData:(NSData *)pcmData {

}

- (void)stopPlay {

}
@end
