//
//  BZQWebRTC.m
//  AudioUnitManager
//
//  Created by BanZhiqiang on 2020/12/30.
//

#import "BZQWebRTC.h"
#include "noise_suppression.h"

@interface BZQWebRTC()
@property (assign, nonatomic) NsHandle * _Nonnull handle;
@property (assign, nonatomic) NSInteger sampleRate; //采样率
@property (assign, nonatomic) NSUInteger lengthLimit; //处理的数据必须大于这个长度
@end

@implementation BZQWebRTC

- (instancetype _Nullable)initWithSampleRate:(NSInteger)fs nsMode:(BZQNSMode)mode{
    if (self = [super init]) {
        _sampleRate = fs;
        _lengthLimit = LimitLength10ms(fs);
        _handle = WebRtcNs_Create();
        int status = WebRtcNs_Init(_handle, (uint32_t)fs);
        if (status != 0) {
            NSLog(@"WebRTC初始化失败！%d", status);
            return nil;
        }

        status = WebRtcNs_set_policy(_handle, (int)mode);
        if (status != 0) {
            NSLog(@"WebRTC设置降噪模式失败！%d", status);
            return nil;
        }
    }
    return self;
}

- (NSData *_Nullable)nsProcess:(NSData *)pcmData {
    NSUInteger length = pcmData.length;
    if (length < self.lengthLimit) {
        return nil;
    }
    short *shortData = (short *)pcmData.bytes;
    //把10ms的音频样本数定义为s10，即sample10ms
    NSInteger s10 = MIN(320, self.sampleRate * 0.01);
    //总的样本数，除以s10，就是我们需要处理的次数
    NSInteger sTot = length / (s10 * 2);
    for(int i = 0; i < sTot; ++i) {
        short in_buffer[160] = {0};
        short out_buffer[160] = {0};
        memcpy(in_buffer, shortData, s10*2); //s10是样本数，乘以2是每个样本的字节数
        short *nsIn[1] = {in_buffer};
        short *nsOut[1] = {out_buffer};
        WebRtcNs_Analyze(_handle, nsIn[0]);
        WebRtcNs_Process(_handle, (const short *const *)nsIn, 1, nsOut);
        memcpy(shortData, out_buffer, s10*2);

        shortData += s10;
    }

    return pcmData;
}

//销毁
- (void)free {
    WebRtcNs_Free(_handle);
}

#pragma mark - Private
//计算10ms的音频需要的长度，采样率*0.01就是样本数量，然后乘以采样位数就是总位数，采样位数默认16位，再除以8就是字节数
inline static NSUInteger LimitLength10ms(NSUInteger rate) {
    return rate * 0.01 * 16 / 8;
}
@end
