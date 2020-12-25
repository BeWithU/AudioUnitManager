//
//  BZQAccompanyRecorder.m
//  AudioUnitManager
//
//  Created by BanZhiqiang on 2020/12/25.
//

#import "BZQAccompanyRecorder.h"
#import <AudioToolbox/AudioConverter.h>
#import <AudioUnit/AudioUnit.h>

const static NSInteger OUTPUT_BUS = 0;
const static NSInteger INPUT_BUS = 1;
const static NSInteger CONST_BUFFER_SIZE = 10000;

@interface BZQAccompanyRecorder ()
@property (assign, nonatomic) AudioUnit recordAudioUnit;
@property (assign, nonatomic) AudioUnit playAudioUnit;

@property (copy, nonatomic) void (^recordBlock)(NSData *);
@property (strong, nonatomic) NSMutableData *recordData; //可以考虑用循环缓冲，否则录制的音频都放到内存，会导致内存暴涨
@property (strong, nonatomic) NSInputStream *inputStream;
@property (assign, nonatomic) NSUInteger readLength;
@end

@implementation BZQAccompanyRecorder

- (instancetype)init {
    if (self = [super init]) {
        [self setupData];
        [self setupAudioUnit];
    }
    return self;
}

#pragma mark - Public

- (void)recordWithBlock:(void (^)(NSData *pcmData))block {
    self.recordBlock = block;
    [self.inputStream open];

    AudioOutputUnitStart(self.recordAudioUnit);
    AudioOutputUnitStart(self.playAudioUnit);
}

- (void)stopRecord {
    AudioOutputUnitStop(self.recordAudioUnit);
    AudioOutputUnitStop(self.playAudioUnit);
}

#pragma mark - Private

- (void)setupData {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"china-x" withExtension:@"pcm"];
    self.inputStream = [NSInputStream inputStreamWithURL:url];

    self.recordData = [NSMutableData data];

    self.readLength = 0;
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
    AudioComponentInstanceNew(component, &_recordAudioUnit);
    AudioComponentInstanceNew(component, &_playAudioUnit);

    AudioStreamBasicDescription pcmFormat = [self.class audioPCMFormat];
    AudioUnitSetProperty(self.recordAudioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &pcmFormat,
                         sizeof(pcmFormat));

    UInt32 enableRecord = 1;
    AudioUnitSetProperty(self.recordAudioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         INPUT_BUS,
                         &enableRecord,
                         sizeof(enableRecord));

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

    //初始化，注意，这里只是初始化
    status = AudioUnitInitialize(self.recordAudioUnit);
    NSLog(@"AudioUnitInitialize record %d", status);
    status = AudioUnitInitialize(self.playAudioUnit);
    NSLog(@"AudioUnitInitialize play %d", status);
}

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

#pragma mark - callback function
static OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData) {
    BZQAccompanyRecorder *recorder = (__bridge BZQAccompanyRecorder *)inRefCon;
    //用来缓存录音数据数据结构
    AudioBufferList *bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers = 1;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    bufferList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);
    //录音渲染完成，把声音数据已经放到bufferList里面了
    OSStatus status = AudioUnitRender(recorder.recordAudioUnit,
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

    //录音完成
    [recorder.recordData appendBytes:bufferData length:bufferSize];

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
    BZQAccompanyRecorder *recorder = (__bridge BZQAccompanyRecorder *)inRefCon;

    Byte *buffer = malloc(CONST_BUFFER_SIZE);
    //length是读出来的音频数据的长度，也就是要播放的音频的长度，所以要复制给ioData对应的mDataByteSize
    NSInteger length = [recorder.inputStream read:buffer maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];

    ioData->mBuffers[0].mDataByteSize = (UInt32)length;
    ioData->mBuffers[1].mDataByteSize = (UInt32)length;
    //这个是伴奏的音频数据
    memcpy(ioData->mBuffers[0].mData, buffer, length);

    //录制的音频
    memset(ioData->mBuffers[1].mData, 0, length);
    NSData *readData = [recorder.recordData subdataWithRange:NSMakeRange(recorder.readLength, length)];
    recorder.readLength += readData.length;
    memcpy(ioData->mBuffers[1].mData, readData.bytes, readData.length);


    NSLog(@"PlayCallback bufferList = %ld", length);

    //判断是否播放完了
    if (length <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [recorder stopRecord];
        });
    }
    return noErr;
}


@end
