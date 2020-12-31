//
//  BZQWebRTCViewController.m
//  AudioUnitManager
//
//  Created by BanZhiqiang on 2020/12/31.
//

#import "BZQWebRTCViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "BZQWebRTC.h"
#import "BZQAudioUnitManager.h"

@interface BZQWebRTCViewController ()

@property (strong, nonatomic) UIButton *playBefortButton;
@property (strong, nonatomic) UIButton *playAfterButton;
@property (strong, nonatomic) NSURL *noiseUrl;
@property (strong, nonatomic) BZQWebRTC *webrtc;
@property (strong, nonatomic) BZQAudioUnitManager *aumanager;

@end

@implementation BZQWebRTCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"测试WebRTC";
    self.view.backgroundColor = UIColor.whiteColor;

    self.navigationItem.hidesBackButton = YES;
    UIBarButtonItem *newBackButton =
        [[UIBarButtonItem alloc] initWithTitle:@"返回"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(backClick:)];
    self.navigationItem.leftBarButtonItem = newBackButton;

    self.playBefortButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:self.playBefortButton];
    self.playBefortButton.frame = CGRectMake(20, 200, 200, 50);
    [self.playBefortButton setTitle:@"播放原来的音频" forState:UIControlStateNormal];
    [self.playBefortButton.titleLabel setTextAlignment:NSTextAlignmentLeft];
    [self.playBefortButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [self.playBefortButton addTarget:self
                              action:@selector(playBeforePCM:)
                    forControlEvents:UIControlEventTouchUpInside];
    self.playBefortButton.tag = 0;

    self.playAfterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:self.playAfterButton];
    self.playAfterButton.frame = CGRectMake(20, 300, 200, 50);
    [self.playAfterButton setTitle:@"播放降噪后的音频" forState:UIControlStateNormal];
    [self.playAfterButton.titleLabel setTextAlignment:NSTextAlignmentLeft];
    [self.playAfterButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [self.playAfterButton addTarget:self
                             action:@selector(playAfterPCM:)
                   forControlEvents:UIControlEventTouchUpInside];
    self.playAfterButton.tag = 0;

    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    self.webrtc = [[BZQWebRTC alloc] initWithSampleRate:16000 nsMode:BZQNSModeAggressive];
    self.noiseUrl = [[NSBundle mainBundle] URLForResource:@"noise" withExtension:@"pcm"];
    self.aumanager = [[BZQAudioUnitManager alloc] initWithSampleRate:16000];
}

#pragma mark - Private
- (void)backClick:(UIBarButtonItem *)sender {
    [self.aumanager stopPlay];
    [self.webrtc free];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)playBeforePCM:(UIButton *)button {
    [self.aumanager stopPlay];
    [self.aumanager clearPlayData];
    if (button.tag == 0) {
        NSData *pcmData = [NSData dataWithContentsOfURL:self.noiseUrl];
        [self.aumanager addPCMData:pcmData];
        [self.aumanager play];
        button.tag = 1;
        [button setTitle:@"暂停播放" forState:UIControlStateNormal];
    } else {
        button.tag = 0;
        [button setTitle:@"播放原来的音频" forState:UIControlStateNormal];
    }
}

- (void)playAfterPCM:(UIButton *)button {
    [self.aumanager stopPlay];
    [self.aumanager clearPlayData];
    if (button.tag == 0) {
        NSData *pcmData = [NSData dataWithContentsOfURL:self.noiseUrl];
        NSData *nsPcmData = [self.webrtc nsProcess:pcmData];
        [self.aumanager addPCMData:nsPcmData];
        [self.aumanager play];
        button.tag = 1;
        [button setTitle:@"暂停播放" forState:UIControlStateNormal];
    } else {
        button.tag = 0;
        [button setTitle:@"播放降噪后的音频" forState:UIControlStateNormal];
    }
}



@end
