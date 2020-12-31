//
//  BZQWebRTCNSRecorder.h
//  AudioUnitManager
//
//  Created by BanZhiqiang on 2020/12/30.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//录音的时候降噪
@interface BZQWebRTCNSRecorder : NSObject

- (void)recordWithBlock:(void (^)(NSData *pcmData))block;
- (void)stopRecord;

@end

NS_ASSUME_NONNULL_END
