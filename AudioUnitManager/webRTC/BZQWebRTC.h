//
//  BZQWebRTC.h
//  AudioUnitManager
//
//  Created by BanZhiqiang on 2020/12/30.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//降噪强度，0: Mild, 1: Medium , 2: Aggressive
typedef NS_ENUM(NSInteger, BZQNSMode) {
    BZQNSModeMild = 0,
    BZQNSModeMedium = 1,
    BZQNSModeAggressive = 2,
};

//针对WebRTC库中，noise_suppression的封装
//noise_suppression有两种，这两种库的参数和使用方式都不太一样，需要注意
//第一种是谷歌抽出来的模块，使用的时候需要引用很多其他的库
//第二种是单独引用noise_suppression.h和.c就可以使用的
@interface BZQWebRTC : NSObject


/// 创建一个降噪对象
/// @param fs 采样率
/// @param mode 降噪强度
- (instancetype _Nullable)initWithSampleRate:(NSInteger)fs nsMode:(BZQNSMode)mode;


/// 处理需要降噪的数据。如果传入的数据小于10ms，则返回空
/// @param pcmData 需要处理的数据
- (NSData *_Nullable)nsProcess:(NSData *)pcmData;

- (void)free; //销毁

@end

NS_ASSUME_NONNULL_END
