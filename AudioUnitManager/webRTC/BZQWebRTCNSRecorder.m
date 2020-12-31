//
//  BZQWebRTCNSRecorder.m
//  AudioUnitManager
//
//  Created by BanZhiqiang on 2020/12/30.
//

#import "BZQWebRTCNSRecorder.h"
#import <AudioUnit/AudioUnit.h>

const static NSInteger INPUT_BUS = 1;
const static NSInteger CONST_BUFFER_SIZE = 10000;

@interface BZQWebRTCNSRecorder ()
@property (assign, nonatomic) AudioUnit recordAudioUnit;

@property (copy, nonatomic) void (^recordBlock)(NSData *);
@end

@implementation BZQWebRTCNSRecorder

- (instancetype)init {
    if (self = [super init]) {
        [self setupAudioUnit];
    }
    return self;
}

#pragma mark - Public

- (void)recordWithBlock:(void (^)(NSData *pcmData))block {
    self.recordBlock = block;

    AudioOutputUnitStart(self.recordAudioUnit);
}

- (void)stopRecord {
    AudioOutputUnitStop(self.recordAudioUnit);
}

#pragma mark - Private

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

    //初始化，注意，这里只是初始化
    status = AudioUnitInitialize(self.recordAudioUnit);
    NSLog(@"AudioUnitInitialize record %d", status);
}

+ (AudioStreamBasicDescription)audioPCMFormat {
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = 16000; //降噪只支持8K，16K，32K
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
    BZQWebRTCNSRecorder *recorder = (__bridge BZQWebRTCNSRecorder *)inRefCon;
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
    if (recorder.recordBlock) {
        recorder.recordBlock([NSData dataWithBytes:bufferData length:bufferSize]);
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

@end
