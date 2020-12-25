//
//  BZQMp3PlayerViewController.m
//  AudioUnitManager
//
//  Created by BanZhiqiang on 2020/12/24.
//

#import "BZQMp3PlayerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "BZQMP3Player.h"

@interface BZQMp3PlayerViewController ()
@property (strong, nonatomic) BZQMP3Player *player;
@property (strong, nonatomic) UIButton *playButton;
@end

@implementation BZQMp3PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"播放Mp3";
    self.view.backgroundColor = UIColor.whiteColor;

    self.navigationItem.hidesBackButton = YES;
    UIBarButtonItem *newBackButton =
        [[UIBarButtonItem alloc] initWithTitle:@"返回"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(backClick:)];
    self.navigationItem.leftBarButtonItem = newBackButton;

    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:self.playButton];
    self.playButton.frame = CGRectMake(20, 200, 200, 50);
    [self.playButton setTitle:@"播放" forState:UIControlStateNormal];
    [self.playButton.titleLabel setTextAlignment:NSTextAlignmentLeft];
    [self.playButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [self.playButton addTarget:self
                        action:@selector(playOrStop:)
              forControlEvents:UIControlEventTouchUpInside];
    self.playButton.tag = 0;

    NSURL *url = [[NSBundle mainBundle] URLForResource:@"color_X_3D" withExtension:@"mp3"];
    self.player = [[BZQMP3Player alloc] initWithUrl:url];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
}

#pragma mark - Private
- (void)backClick:(UIBarButtonItem *)sender {
    [self.player stop];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)playOrStop:(UIButton *)button {
    if (button.tag == 0) {
        [self.player play];
        button.tag = 1;
        [self.playButton setTitle:@"暂停" forState:UIControlStateNormal];
    } else {
        [self.player pause];
        button.tag = 0;
        [self.playButton setTitle:@"播放" forState:UIControlStateNormal];
    }
}

@end
