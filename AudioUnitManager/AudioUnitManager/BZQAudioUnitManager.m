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

@property (assign, nonatomic) NSInteger ar;
@property (strong, nonatomic) NSMutableData *pcmData;
@property (strong, nonatomic) NSLock *lock;
@property (assign, nonatomic) NSInteger usedLength;

@property (copy, nonatomic) void (^recordBlock)(NSData *, CGFloat);
@property (assign, nonatomic) AudioUnit recordAudioUnit;
@property (assign, nonatomic) AudioUnit playAudioUnit;

@end

@implementation BZQAudioUnitManager

- (instancetype)initWithSampleRate:(NSInteger)ar {
    if (self = [super init]) {
        _ar = ar;
        [self setup];
    }
    return self;
}

- (void)setup {
    self.pcmData = [NSMutableData new];
    self.lock = [NSLock new];
    self.usedLength = 0;

    [self setupAudioUnit];
}

#pragma mark - Private
#pragma mark - AudioUnit相关配置
//简称ASBD，就是PCM格式音频的描述文件，可以设置采样率，声道数量等
+ (AudioStreamBasicDescription)audioPCMFormat {
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = 44100;
    audioFormat.mFormatID = kAudioFormatLinearPCM; //音频格式
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mBytesPerFrame = 2;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBitsPerChannel = 16;

    return audioFormat;
}

- (void)setupAudioUnit {
    OSStatus status = noErr;
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    AudioComponent component = AudioComponentFindNext(NULL, &audioDesc);
    //播放和录音用相同的描述文件即可，下面两行代码执行完两个音频单元就创建好了
    AudioComponentInstanceNew(component, &_recordAudioUnit);
    AudioComponentInstanceNew(component, &_playAudioUnit);

    //设置录音相关属性，即INPUT_BUS相关
    //录音的格式，注意这里设置的是INPUT_BUS的kAudioUnitScope_Output
    AudioStreamBasicDescription pcmFormat = [self.class audioPCMFormat];
    pcmFormat.mSampleRate = self.ar;
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
    if (manager.recordBlock) {
        //下面的代码是把PCM采样位数16位的数据计算分贝，其他采样位数的需要调整
        short *shortData = (short *)bufferData;
        NSInteger len = bufferSize / 2;
        long long sum = 0;
        for(NSInteger i=0;i<len;++i) {
            sum += shortData[i]*shortData[i];
        }
        CGFloat db = 10 * log10((CGFloat)sum / bufferSize);
        NSData *data = [[NSData alloc] initWithBytes:bufferData length:bufferSize];
        manager.recordBlock(data, db);
    }

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
    NSData *needPlayData = [manager readDataWithLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];
    memcpy(ioData->mBuffers[0].mData, needPlayData.bytes, needPlayData.length);
    ioData->mBuffers[0].mDataByteSize = (UInt32)needPlayData.length;

    //如果不是流式的持续播放，那这里可能需要判断是否播放完了，根据具体逻辑把下面的注释打开
//    if (needPlayData.length <= 0) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [manager stopPlay];
//        });
//    }
    return noErr;
}

#pragma mark - Public
- (void)recordWithBlock:(void (^)(NSData *pcmData, CGFloat db))block {
    self.recordBlock = block;
    AudioOutputUnitStart(self.recordAudioUnit);
}

- (void)stopRecord {
    AudioOutputUnitStop(self.recordAudioUnit);
    //如果确定不录音了，这里可以释放对应的AU。后面需要录音就重新创建
    //AudioUnitUninitialize(self.recordAudioUnit);
}

- (void)play {
    AudioOutputUnitStart(self.playAudioUnit);
}

- (void)addPCMData:(NSData *)pcmData {
    [self.lock lock];
    [self.pcmData appendData:pcmData];
    [self.lock unlock];
}

- (void)stopPlay {
    AudioOutputUnitStop(self.playAudioUnit);
}

- (void)clearPlayData {
    [self.lock lock];
    self.pcmData.length = 0;
    self.usedLength = 0;
    [self.lock unlock];
}

#pragma mark - Private
- (NSData *)readDataWithLength:(NSInteger)length {
    [self.lock lock];
    NSRange range = NSMakeRange(self.usedLength, length);
    if (self.usedLength + length > self.pcmData.length) {
        range.length = self.pcmData.length - self.usedLength;
    }
    NSData *data = [self.pcmData subdataWithRange:range];
    self.usedLength = range.location + range.length;
    [self.lock unlock];
    return data;
}
@end
