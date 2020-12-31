//
//  BZQAudioUnitManager.h
//  AudioUnitManager
//
//  Created by bzq on 2020/12/3.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

//通过这个单例对象管理你的音频，目前只支持录制和播放PCM格式数据
//具体每个方法，参数都是做什么的，参考BZQRecordPlayViewController
@interface BZQAudioUnitManager : NSObject

- (instancetype)initWithSampleRate:(NSInteger)ar;

- (void)recordWithBlock:(void (^)(NSData *pcmData, CGFloat db))block;
- (void)stopRecord;

- (void)play;
//调用play之后，可以多次调用addPCMData添加数据。
//场景比如从云端下发的一段一段的数据可以通过这个方法添加后播放。
- (void)addPCMData:(NSData *)pcmData;
- (void)stopPlay;
- (void)clearPlayData;
@end

NS_ASSUME_NONNULL_END
