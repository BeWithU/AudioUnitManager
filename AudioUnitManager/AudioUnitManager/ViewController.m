//
//  ViewController.m
//  AudioUnitManager
//
//  Created by bzq on 2020/11/30.
//

#import "ViewController.h"

@interface ViewController ()
@property (strong, nonatomic) UILabel *label;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.label = [UILabel new];
    self.label.frame = CGRectMake(0, 100, self.view.bounds.size.width, 50);
    self.label.text = @"AudioUnitManager";
    self.label.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.label];
}


@end
