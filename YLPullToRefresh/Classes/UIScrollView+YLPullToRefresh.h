//
// UIScrollView+YLPullToRefresh.h
//
//  Created by lifuqing on 2019/5/21.
//  Copyright © 2019 Home. All rights reserved.
//
//

#import <UIKit/UIKit.h>


@class YLPullToRefreshView;

@interface UIScrollView (YLPullToRefresh)

- (void)addPullToRefreshWithActionHandler:(void (^)(void))actionHandler;
- (void)triggerPullToRefresh;

@property (nonatomic, strong, readonly) YLPullToRefreshView *pullToRefreshView;
@property (nonatomic, assign) BOOL showsPullToRefresh;

@end


@protocol YLPullToRefreshProtocol<NSObject>

@optional
- (void)pullToRefreshViewDidScrollWithProgress:(CGFloat)progress;

@end


typedef NS_ENUM(NSUInteger, YLPullToRefreshState) {
    YLPullToRefreshStateStopped = 0,
    YLPullToRefreshStateTriggered,
    YLPullToRefreshStateLoading,
    YLPullToRefreshStateAll = 10
};

typedef NS_ENUM(NSUInteger, YLPullToRefreshArrowPosition) {
    YLPullToRefreshArrowPositionDefault = 0, //固定在左侧
    YLPullToRefreshArrowPositionAnimated, //跟随主、副标题动态
};

typedef NS_ENUM(NSUInteger, YLPullToRefreshStyle) {
    YLPullToRefreshStyleDefault = 0, //箭头向下，外加进度圈
    YLPullToRefreshStyleArrowRotated, //箭头旋转
};

typedef NS_ENUM(NSUInteger, YLPullToRefreshActivityStyle) {
    YLPullToRefreshActivityStyleDefault = 0, //默认使用自定义的豁口圆圈旋转
    YLPullToRefreshActivityStyleSystem,      //系统自带的菊花样式
};

@interface YLPullToRefreshView : UIView

@property (nonatomic, strong) UIColor *arrowColor;
@property (nonatomic, assign) CGFloat arrowLineWidth;//默认1
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *subtitleLabel;
@property (nonatomic, strong, readwrite) UIColor *activityIndicatorViewColor;

///loading指示器样式，默认YLPullToRefreshActivityStyleDefault
@property (nonatomic, readwrite) YLPullToRefreshActivityStyle activityStyle;
///仅当activityStyle=YLPullToRefreshActivityStyleSystem的时候此值才有意义
@property (nonatomic, readwrite) UIActivityIndicatorViewStyle activityIndicatorViewStyle;

@property (nonatomic, readonly) YLPullToRefreshState state;

@property (nonatomic, readwrite) YLPullToRefreshArrowPosition position;
@property (nonatomic, readwrite) YLPullToRefreshStyle style;
@property (nonatomic, assign) BOOL refreshSound; // 播放下拉刷新完成的声音, 默认 YES

- (void)setTitle:(NSString *)title forState:(YLPullToRefreshState)state;
- (void)setSubtitle:(NSString *)subtitle forState:(YLPullToRefreshState)state;
- (void)setCustomView:(UIView<YLPullToRefreshProtocol> *)view forState:(YLPullToRefreshState)state;

- (void)startAnimating;
- (void)stopAnimating;

@end
