//
//  YLViewController.m
//  YLPullToRefresh
//
//  Created by lifuqing on 07/03/2019.
//  Copyright (c) 2019 lifuqing. All rights reserved.
//

#import "YLViewController.h"
#import "YLPullToRefresh.h"

@interface YLViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSMutableArray *dataSource;
@property (nonatomic, strong) UITableView *tableView;

@end

@implementation YLViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"demo";
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithTitle:@"切为预加载" style:UIBarButtonItemStylePlain target:self action:@selector(rightItemClick:)];
    
    self.navigationItem.rightBarButtonItem = rightItem;
    [self.view addSubview:self.tableView];
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    [self setupDataSource];
    
    __weak YLViewController *weakSelf = self;
    
    // setup pull-to-refresh
    [self.tableView addPullToRefreshWithActionHandler:^{
        [weakSelf.tableView.pullToLoadMoreView removeNoMoreData];
        [weakSelf insertRowAtTop];
    }];
    //    self.tableView.pullToRefreshView.arrowColor = [UIColor blueColor];
    
    // setup infinite scrolling
    [self.tableView addPullToLoadMoreWithActionHandler:^{
        [weakSelf insertRowAtBottom];
    }];
    //    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
    //    v.backgroundColor = [UIColor redColor];
    //    [self.tableView.pullToLoadMoreView setCustomView:v forState:LJPullToLoadMoreStateNoMoreData];
    self.tableView.pullToLoadMoreView.preLoad = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tableView triggerPullToRefresh];
}

#pragma mark - Actions
- (void)rightItemClick:(UIBarButtonItem *)sender {
    self.tableView.pullToLoadMoreView.preLoad = !self.tableView.pullToLoadMoreView.preLoad;
    sender.title = self.tableView.pullToLoadMoreView.preLoad ? @"切位正常加载" : @"切为预加载";
}

- (void)setupDataSource {
    self.dataSource = [NSMutableArray array];
    for(int i=0; i<15; i++)
        [self.dataSource addObject:[NSDate dateWithTimeIntervalSinceNow:-(i*90)]];
}

- (void)addData {
    for(int i=0; i<15; i++)
        [self.dataSource addObject:[NSDate dateWithTimeIntervalSinceNow:-(i*90)]];
}

- (void)insertRowAtTop {
    __weak YLViewController *weakSelf = self;
    
    int64_t delayInSeconds = 1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [weakSelf setupDataSource];
        [weakSelf.tableView reloadData];
        [weakSelf.tableView.pullToRefreshView stopAnimating];
    });
}


- (void)insertRowAtBottom {
    
    if (self.dataSource.count > 150) {
        [self.tableView.pullToLoadMoreView stopAnimatingWithNoMoreData];
    }
    else {
        [self addData];
        [self.tableView reloadData];
        [self.tableView.pullToLoadMoreView stopAnimating];
    }
    
    //    __weak YLViewController *weakSelf = self;
    //
    //    int64_t delayInSeconds = 1;
    //    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    //    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    //        [self addData];
    //        [weakSelf.tableView reloadData];
    //
    //        if (self.dataSource.count > 40) {//no more
    //            [weakSelf.tableView.pullToLoadMoreView stopAnimatingWithNoMoreData];
    //        }
    //        else {
    //            [weakSelf.tableView.pullToLoadMoreView stopAnimating];
    //        }
    //    });
}


- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        _tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        
        _tableView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
        
        if (@available(iOS 11, *)) {
            _tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
            _tableView.estimatedRowHeight = 0;
            _tableView.estimatedSectionHeaderHeight = 0;
            _tableView.estimatedSectionFooterHeight = 0;
        }
    }
    return _tableView;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"Cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    
    if (cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    
    NSDate *date = [self.dataSource objectAtIndex:indexPath.row];
    cell.textLabel.text = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


@end
