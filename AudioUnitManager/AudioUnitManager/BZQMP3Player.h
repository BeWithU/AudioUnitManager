//
//  BZQMP3Player.h
//  AudioUnitManager
//
//  Created by BanZhiqiang on 2020/12/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BZQMP3Player : NSObject

- (instancetype)initWithUrl:(NSURL *)url;

+ (instancetype)streamPlayer;
- (void)addMp3Data:(NSData *)data;

- (void)play;
- (void)pause;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
