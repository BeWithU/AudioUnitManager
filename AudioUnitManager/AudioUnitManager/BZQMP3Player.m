//
//  BZQMP3Player.m
//  AudioUnitManager
//
//  Created by BanZhiqiang on 2020/12/24.
//

#import "BZQMP3Player.h"
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioConverter.h>

const static NSInteger OUTPUT_BUS = 0;
const static NSInteger CONST_BUFFER_SIZE = 5000;
const static NSInteger NO_MORE_DATA = -100000;

typedef NS_ENUM(NSInteger, BZQPlayMode) {
    BZQPlayModeFile = 0,
    BZQPlayModeStream = 1
};

@interface BZQMP3Player()

@property (assign, nonatomic) AudioUnit playUnit;
@property (assign, nonatomic) AudioConverterRef audioConverter;
@property (assign, nonatomic) AudioStreamBasicDescription mp3FileFormat;
//获取格式，转码需要的属性
@property (assign, nonatomic) AudioFileID audioFileID;
@property (assign, nonatomic) AudioStreamPacketDescription *packetFormat;
@property (assign, nonatomic) SInt64 startingPacket;
@property (assign, nonatomic) Byte *convertBuffer;
@property (assign, nonatomic) AudioBufferList *bufferList;

//具体业务属性
@property (assign, nonatomic) BZQPlayMode playMode;

@end

@implementation BZQMP3Player
- (instancetype)init {
    if (self = [super init]) {
        [self setupAudioUnit];
        [self setupData];
    }
    return self;
}

- (instancetype)initWithUrl:(NSURL *)url {
    if (self = [super init]) {
        _playMode = BZQPlayModeFile;
        OSStatus status = AudioFileOpenURL((__bridge CFURLRef)url,
                                           kAudioFileReadPermission,
                                           0,
                                           &_audioFileID);
        if (status) {
            NSLog(@"打开url失败！ url=%@", url);
            _mp3FileFormat = [self.class audioMP3Format];
        } else {
            uint32_t size = sizeof(AudioStreamBasicDescription);
            status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyDataFormat, &size, &(_mp3FileFormat));
            if (status) {
                NSLog(@"读取文件格式失败！status = %d", status);
                _mp3FileFormat = [self.class audioMP3Format];
            }
        }

        [self setupAudioUnit];
        [self setupData];
    }
    return self;
}

#pragma mark - Public
+ (instancetype)streamPlayer {
    return [BZQMP3Player new]; //TODO 
}

- (void)addMp3Data:(NSData *)data {
    //TODO
}

- (void)play {
    AudioOutputUnitStart(self.playUnit);
}


- (void)pause {
    AudioOutputUnitStop(self.playUnit);
}

- (void)stop {
    AudioOutputUnitStop(self.playUnit);
    AudioUnitUninitialize(self.playUnit);
}

#pragma mark - Private
- (void)setupData {
    self.startingPacket = 0;
    self.convertBuffer = malloc(CONST_BUFFER_SIZE * 2);
    uint32_t sizePerPacket = self.mp3FileFormat.mFramesPerPacket;
    if (sizePerPacket == 0) {
        uint32_t size = sizeof(sizePerPacket);
        AudioFileGetProperty(self.audioFileID,
                             kAudioFilePropertyMaximumPacketSize,
                             &size,
                             &sizePerPacket);
    }

    self.packetFormat = malloc(sizeof(AudioStreamPacketDescription));
    //AudioBufferList默认只有一个声道，所以立体声的缓存申请内存的时候要加一个AudioBuffer的size
    self.bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) + sizeof(AudioBuffer));
    self.bufferList->mNumberBuffers = 2;
    self.bufferList->mBuffers[0].mNumberChannels = 1;
    self.bufferList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    self.bufferList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);
    self.bufferList->mBuffers[1].mNumberChannels = 1;
    self.bufferList->mBuffers[1].mDataByteSize = CONST_BUFFER_SIZE;
    self.bufferList->mBuffers[1].mData = malloc(CONST_BUFFER_SIZE);
}

- (void)setupAudioUnit {
    OSStatus status = noErr;

    AudioStreamBasicDescription outFormat = [self.class audioPCMFormat];
    AudioConverterNew(&_mp3FileFormat, &outFormat, &_audioConverter);

    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    AudioComponent component = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(component, &_playUnit);

    AudioStreamBasicDescription outputFormat = [self.class audioPCMFormat];
    status = AudioUnitSetProperty(self.playUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &outputFormat,
                         sizeof(outputFormat));

    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(self.playUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));


    status = AudioUnitInitialize(self.playUnit);
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
    audioFormat.mChannelsPerFrame = 2; //立体声
    audioFormat.mBitsPerChannel = 16;

    return audioFormat;
}

+ (AudioStreamBasicDescription)audioMP3Format {
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = 16000;
    audioFormat.mFormatID = kAudioFormatMPEGLayer3;
    audioFormat.mFramesPerPacket = 576; //采样个数，就是说一帧里面有多少个样本
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBitsPerChannel = 0;
    audioFormat.mBytesPerPacket = 0;
    audioFormat.mBytesPerFrame = 0;
    return audioFormat;
}

static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    BZQMP3Player *player = (__bridge BZQMP3Player *)inRefCon;

    OSStatus status = AudioConverterFillComplexBuffer(player.audioConverter,
                                                      MP3InputDataProc,
                                                      inRefCon,
                                                      &inNumberFrames,
                                                      player.bufferList,
                                                      NULL);
    NSLog(@"buffer left %u, right %u",
          player.bufferList->mBuffers[0].mDataByteSize,
          player.bufferList->mBuffers[1].mDataByteSize);
    if (status == NO_MORE_DATA) {
        memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);
        memset(ioData->mBuffers[1].mData, 0, ioData->mBuffers[1].mDataByteSize);
        return noErr;
    }

    UInt32 nums = player.bufferList->mNumberBuffers;
    for(UInt32 i=0;i<nums;++i) {
        memcpy(ioData->mBuffers[i].mData,
               player.bufferList->mBuffers[i].mData,
               player.bufferList->mBuffers[i].mDataByteSize);
        ioData->mBuffers[i].mDataByteSize = player.bufferList->mBuffers[i].mDataByteSize;
    }

    return noErr;
}

//读取本地的MP3格式的数据，然后通过ioData输出，外面拿到的就是转换好的PCM格式数据
static OSStatus MP3InputDataProc(AudioConverterRef inAudioConverter,
                                 UInt32 *ioNumberDataPackets,
                                 AudioBufferList *ioData,
                                 AudioStreamPacketDescription **outDataPacketDescription,
                                 void *inUserData) {
    BZQMP3Player *player = (__bridge  BZQMP3Player *)(inUserData);
    UInt32 byteSize = CONST_BUFFER_SIZE;
    OSStatus status = AudioFileReadPacketData(player.audioFileID, NO, &byteSize, player.packetFormat, player.startingPacket, ioNumberDataPackets, player.convertBuffer);
    if (outDataPacketDescription) {
        *outDataPacketDescription = player.packetFormat;
    }

    NSLog(@"MP3InputDataProc %u", byteSize);

    if (!status && ioNumberDataPackets > 0) {
        ioData->mBuffers[0].mDataByteSize = byteSize;
        ioData->mBuffers[0].mData = player.convertBuffer;
        player.startingPacket += *ioNumberDataPackets;
        return noErr;
    } else {
        return NO_MORE_DATA;
    }

    return noErr;
}

@end
