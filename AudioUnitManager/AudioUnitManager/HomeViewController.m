//
//  HomeViewController.m
//  AudioUnitManager
//
//  Created by bzq on 2020/11/30.
//

#import "HomeViewController.h"
#import "BZQRecordPlayViewController.h"
#import "BZQMp3PlayerViewController.h"
#import "BZQAccompanyViewController.h"

static NSString *const TableViewCellID = @"TableViewCellID";

@interface HomeViewController ()
@property (copy, nonatomic) NSArray *datasource;
@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.clearsSelectionOnViewWillAppear = NO;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:TableViewCellID];
    self.datasource = @[@"录制和播放PCM", @"播放MP3", @"边录边播"];
}

#pragma mark - Table view data source

#pragma mark - UITableViewDelegate & DataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.datasource.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 55.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:TableViewCellID
                                                            forIndexPath:indexPath];
    cell.textLabel.text = self.datasource[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.row) {
        case 0:{
            BZQRecordPlayViewController *rpvc = [BZQRecordPlayViewController new];
            [self.navigationController pushViewController:rpvc animated:YES];
        } break;
        case 1:{
            BZQMp3PlayerViewController *mp3PlayerVC = [BZQMp3PlayerViewController new];
            [self.navigationController pushViewController:mp3PlayerVC animated:YES];
        } break;
        case 2:{
            BZQAccompanyViewController *accompanyVC = [BZQAccompanyViewController new];
            [self.navigationController pushViewController:accompanyVC animated:YES];
        } break;
        default:
            break;
    }
}

@end
