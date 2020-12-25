//
//  BZQAccompanyRecorder.h
//  AudioUnitManager
//
//  Created by BanZhiqiang on 2020/12/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

//边录边播
@interface BZQAccompanyRecorder : NSObject

- (void)recordWithBlock:(void (^)(NSData *pcmData))block;
- (void)stopRecord;

@end

NS_ASSUME_NONNULL_END
