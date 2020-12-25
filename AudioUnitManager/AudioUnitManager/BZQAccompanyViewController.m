//
//  BZQAccompanyViewController.m
//  AudioUnitManager
//
//  Created by BanZhiqiang on 2020/12/25.
//

#import "BZQAccompanyViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "BZQAccompanyRecorder.h"

@interface BZQAccompanyViewController ()
@property (strong, nonatomic) BZQAccompanyRecorder *recorder;
@property (strong, nonatomic) UIButton *button;
@end

@implementation BZQAccompanyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"伴奏录音";
    self.view.backgroundColor = UIColor.whiteColor;

    self.navigationItem.hidesBackButton = YES;
    UIBarButtonItem *newBackButton =
        [[UIBarButtonItem alloc] initWithTitle:@"返回"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(backClick:)];
    self.navigationItem.leftBarButtonItem = newBackButton;

    self.button = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:self.button];
    self.button.frame = CGRectMake(20, 200, 200, 50);
    [self.button setTitle:@"录音" forState:UIControlStateNormal];
    [self.button.titleLabel setTextAlignment:NSTextAlignmentLeft];
    [self.button setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [self.button addTarget:self
                    action:@selector(startRecord:)
          forControlEvents:UIControlEventTouchUpInside];
    self.button.tag = 0;

    self.recorder = [[BZQAccompanyRecorder alloc] init];

    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                     withOptions:AVAudioSessionCategoryOptionAllowBluetoothA2DP
                                           error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

#pragma mark - Private
- (void)backClick:(UIBarButtonItem *)sender {
    [self.recorder stopRecord];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)startRecord:(UIButton *)button {
    if (button.tag == 0) {
        button.tag = 1;
        [self.recorder recordWithBlock:^(NSData * _Nonnull pcmData) {

        }];
    } else {
        button.tag = 0;
        [self.recorder stopRecord];
    }
}

@end
