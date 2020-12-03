//
//  BZQAudioUnitManager.h
//  AudioUnitManager
//
//  Created by bzq on 2020/12/3.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

//通过这个单例对象管理你的音频
@interface BZQAudioUnitManager : NSObject

+ (instancetype)sharedManager;

- (void)recordWithBlock:(void (^)(NSData *pcmData, CGFloat vol))block;
- (void)stopRecord;

- (void)play;
- (void)addPCMData:(NSData *)pcmData;
- (void)stopPlay;
@end

NS_ASSUME_NONNULL_END
