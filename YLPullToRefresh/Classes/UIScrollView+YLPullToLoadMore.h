//
// UIScrollView+YLPullToLoadMore.h
//
//  Created by lifuqing on 2019/5/21.
//  Copyright © 2019 Home. All rights reserved.
//
//

#import <UIKit/UIKit.h>

@class YLPullToLoadMoreView;

@interface UIScrollView (YLPullToLoadMore)

- (void)addPullToLoadMoreWithActionHandler:(void (^)(void))actionHandler;
- (void)triggerPullToLoadMore;

@property (nonatomic, strong, readonly) YLPullToLoadMoreView *pullToLoadMoreView;
@property (nonatomic, assign) BOOL showsPullToLoadMore;

@end

///加载更多的状态，如果要新增类型 需要修改内部的代码
typedef NS_ENUM(NSUInteger, YLPullToLoadMoreState) {
    YLPullToLoadMoreStateStopped = 0,
    YLPullToLoadMoreStatePreLoadTriggered,
    YLPullToLoadMoreStateTriggered,
    YLPullToLoadMoreStateLoading,
    YLPullToLoadMoreStateNoMoreData,
    YLPullToLoadMoreStateAll = 10
};

@interface YLPullToLoadMoreView : UIView
/// YLPullToLoadMoreStateNoMoreData 状态下字体颜色，仅当调用stopAnimatingWithNoMoreData才有效
@property (nonatomic, readwrite) UIColor *textColor;
@property (nonatomic, readwrite) UIActivityIndicatorViewStyle activityIndicatorViewStyle;
@property (nonatomic, readonly) CGFloat originalBottomInset;
@property (nonatomic, readonly) YLPullToLoadMoreState state;
@property (nonatomic, readwrite) BOOL enabled;
///没有更多数据时展示的文本内容，默认"没有更多数据啦"
@property (nonatomic, copy) NSString *noMoreDataText;

#pragma mark - 预加载相关
///预加载,默认NO
@property (nonatomic, readwrite, assign) BOOL preLoad;
//提前几屏预加载，默认3
@property (nonatomic, assign) NSInteger previousScreenCount;
///上一状态，主要用于判断是预加载YLPullToLoadMoreStatePreLoadTriggered还是YLPullToLoadMoreStateTriggered
@property (nonatomic, readonly) YLPullToLoadMoreState previousState;

#pragma mark - public
- (void)setCustomView:(UIView *)view forState:(YLPullToLoadMoreState)state;

- (void)startAnimating;
///还有更多数据的时候调用此方法停止
- (void)stopAnimating;
///无更多时显示无更多数据标签,调用此方法停止
- (void)stopAnimatingWithNoMoreData;

@end



@interface YLPullToLoadMoreView (YLMoreProtect)

/// 移除无更多数据标签，在下拉刷新内部使用，外部无需调用
- (void)removeNoMoreData;


@end

