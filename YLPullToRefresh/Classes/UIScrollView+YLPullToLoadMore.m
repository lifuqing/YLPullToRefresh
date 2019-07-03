//
// UIScrollView+YLPullToLoadMore.m
//
//  Created by lifuqing on 2019/5/21.
//  Copyright © 2019 Home. All rights reserved.
//
//

#import <QuartzCore/QuartzCore.h>
#import "UIScrollView+YLPullToLoadMore.h"


static CGFloat const YLPullToLoadMoreViewHeight = 60;


@interface YLPullToLoadMoreView ()

@property (nonatomic, copy) void (^pullToLoadMoreHandler)(void);

@property (nonatomic, strong) UILabel *titleLabel;

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, readwrite) YLPullToLoadMoreState state;
@property (nonatomic, readwrite) YLPullToLoadMoreState previousState;
@property (nonatomic, strong) NSMutableArray *viewForState;
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, readwrite) CGFloat originalBottomInset;
@property (nonatomic, assign) BOOL isObserving;

- (void)resetScrollViewContentInset;
- (void)setScrollViewContentInsetForPullToLoadMore;
- (void)setScrollViewContentInset:(UIEdgeInsets)insets;

@end



@implementation YLPullToLoadMoreView (YLMoreProtect)

/// 移除无更多数据标签，在下拉刷新内部使用，外部无需调用
- (void)removeNoMoreData {
    self.state = YLPullToLoadMoreStateStopped;
}

@end

#pragma mark - UIScrollView (YLPullToLoadMoreView)
#import <objc/runtime.h>

static char UIScrollViewPullToLoadMoreView;


@implementation UIScrollView (YLPullToLoadMore)

@dynamic pullToLoadMoreView;

- (void)addPullToLoadMoreWithActionHandler:(void (^)(void))actionHandler {
    
    if(!self.pullToLoadMoreView) {
        YLPullToLoadMoreView *view = [[YLPullToLoadMoreView alloc] initWithFrame:CGRectMake(0, self.contentSize.height, self.bounds.size.width, YLPullToLoadMoreViewHeight)];
        view.pullToLoadMoreHandler = actionHandler;
        view.scrollView = self;
        [self addSubview:view];
        
        view.originalBottomInset = self.contentInset.bottom;
        self.pullToLoadMoreView = view;
        self.showsPullToLoadMore = YES;
    }
}


- (void)triggerPullToLoadMore {
    self.pullToLoadMoreView.state = YLPullToLoadMoreStateTriggered;
    [self.pullToLoadMoreView startAnimating];
}

- (void)setPullToLoadMoreView:(YLPullToLoadMoreView *)pullToLoadMoreView {
    [self willChangeValueForKey:@"UIScrollViewPullToLoadMoreView"];
    objc_setAssociatedObject(self, &UIScrollViewPullToLoadMoreView,
                             pullToLoadMoreView,
                             OBJC_ASSOCIATION_ASSIGN);
    [self didChangeValueForKey:@"UIScrollViewPullToLoadMoreView"];
}

- (YLPullToLoadMoreView *)pullToLoadMoreView {
    return objc_getAssociatedObject(self, &UIScrollViewPullToLoadMoreView);
}

- (void)setShowsPullToLoadMore:(BOOL)showsPullToLoadMore {
    self.pullToLoadMoreView.hidden = !showsPullToLoadMore;
    
    if(!showsPullToLoadMore) {
        if (self.pullToLoadMoreView.isObserving) {
            [self removeObserver:self.pullToLoadMoreView forKeyPath:@"contentOffset"];
            [self removeObserver:self.pullToLoadMoreView forKeyPath:@"contentSize"];
            [self.pullToLoadMoreView resetScrollViewContentInset];
            self.pullToLoadMoreView.isObserving = NO;
        }
    }
    else {
        if (!self.pullToLoadMoreView.isObserving) {
            [self addObserver:self.pullToLoadMoreView forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
            [self addObserver:self.pullToLoadMoreView forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
            [self.pullToLoadMoreView setScrollViewContentInsetForPullToLoadMore];
            self.pullToLoadMoreView.isObserving = YES;
            
            [self.pullToLoadMoreView setNeedsLayout];
            self.pullToLoadMoreView.frame = CGRectMake(0, self.contentSize.height, self.pullToLoadMoreView.bounds.size.width, YLPullToLoadMoreViewHeight);
        }
    }
}

- (BOOL)showsPullToLoadMore {
    return !self.pullToLoadMoreView.hidden;
}

@end


#pragma mark - YLPullToLoadMoreView
@implementation YLPullToLoadMoreView

// public properties
@synthesize pullToLoadMoreHandler, activityIndicatorViewStyle;

@synthesize state = _state;
@synthesize scrollView = _scrollView;
@synthesize activityIndicatorView = _activityIndicatorView;


- (id)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        
        self.textColor = [UIColor grayColor];
        // default styling values
        self.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.state = YLPullToLoadMoreStateStopped;
        self.preLoad = NO;
        self.previousScreenCount = 3;
        self.enabled = YES;
        self.noMoreDataText = @"没有更多数据啦";
        self.viewForState = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", @"", @"", nil];
    }
    
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (self.superview && newSuperview == nil) {
        UIScrollView *scrollView = (UIScrollView *)self.superview;
        if (scrollView.showsPullToLoadMore) {
          if (self.isObserving) {
            [scrollView removeObserver:self forKeyPath:@"contentOffset"];
            [scrollView removeObserver:self forKeyPath:@"contentSize"];
            self.isObserving = NO;
          }
        }
    }
}

- (void)layoutSubviews {
    for(id otherView in self.viewForState) {
        if([otherView isKindOfClass:[UIView class]])
            [otherView removeFromSuperview];
    }
    
    id customView = [self.viewForState objectAtIndex:self.state];
    BOOL hasCustomView = [customView isKindOfClass:[UIView class]];
    
    self.titleLabel.hidden = hasCustomView;
    
    if(hasCustomView) {
        [self addSubview:customView];
        CGRect viewBounds = [customView bounds];
        CGPoint origin = CGPointMake(roundf((self.bounds.size.width-viewBounds.size.width)/2), roundf((self.bounds.size.height-viewBounds.size.height)/2));
        [customView setFrame:CGRectMake(origin.x, origin.y, viewBounds.size.width, viewBounds.size.height)];
    }
    else {
        self.titleLabel.hidden = self.state != YLPullToLoadMoreStateNoMoreData;
        self.titleLabel.text = self.noMoreDataText;
        
        CGRect viewBounds = [self.activityIndicatorView bounds];
        CGPoint origin = CGPointMake(roundf((self.bounds.size.width-viewBounds.size.width)/2), roundf((self.bounds.size.height-viewBounds.size.height)/2));
        [self.activityIndicatorView setFrame:CGRectMake(origin.x, origin.y, viewBounds.size.width, viewBounds.size.height)];
        self.activityIndicatorView.center = CGPointMake(self.bounds.size.width/2.0, self.bounds.size.height/2.0);
        
        self.titleLabel.center = CGPointMake(self.bounds.size.width/2.0, self.bounds.size.height/2.0);
    }
}

#pragma mark - Scroll View

- (void)resetScrollViewContentInset {
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    currentInsets.bottom = self.originalBottomInset;
    [self setScrollViewContentInset:currentInsets];
}

- (void)setScrollViewContentInsetForPullToLoadMore {
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    currentInsets.bottom = self.originalBottomInset + YLPullToLoadMoreViewHeight;
    [self setScrollViewContentInset:currentInsets];
}

- (void)setScrollViewContentInset:(UIEdgeInsets)contentInset {
    [UIView animateWithDuration:0.3
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.scrollView.contentInset = contentInset;
                     }
                     completion:NULL];
}

#pragma mark - Observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {    
    if([keyPath isEqualToString:@"contentOffset"])
        [self scrollViewDidScroll:[[change valueForKey:NSKeyValueChangeNewKey] CGPointValue]];
    else if([keyPath isEqualToString:@"contentSize"]) {
        [self layoutSubviews];
        self.frame = CGRectMake(0, self.scrollView.contentSize.height, self.bounds.size.width, YLPullToLoadMoreViewHeight);
    }
}

- (void)scrollViewDidScroll:(CGPoint)contentOffset {
    if (contentOffset.y <= 0) {
        return;
    }
    
    if(self.state != YLPullToLoadMoreStateLoading && self.enabled) {
        //当前contentsize
        CGFloat scrollViewContentHeight = self.scrollView.contentSize.height;
        //滚动到底部的偏移量
        CGFloat scrollOffsetThreshold = scrollViewContentHeight - self.scrollView.bounds.size.height;
        
        if (self.preLoad) {
            //触发预加载的时候的偏移量,当页面滚动超过80%的时候或者可以提前两屏幕的时候触发预加载
            CGFloat preLoadScrollOffsetThreshold = scrollOffsetThreshold - MIN(0.2 * scrollViewContentHeight, self.previousScreenCount * self.scrollView.bounds.size.height);
            //缓冲高度，在预加载触发之后的80像素高度的缓冲区域内 都可以出发预加载
            CGFloat bufferHeight = 80;
            
            if(self.state == YLPullToLoadMoreStatePreLoadTriggered || (!self.scrollView.isDragging && self.state == YLPullToLoadMoreStateTriggered))
                self.state = YLPullToLoadMoreStateLoading;
            else if(contentOffset.y > preLoadScrollOffsetThreshold && self.state == YLPullToLoadMoreStateStopped) {
                if (contentOffset.y < preLoadScrollOffsetThreshold + bufferHeight) {
                    self.state = YLPullToLoadMoreStatePreLoadTriggered;
                }
                else if (contentOffset.y > scrollOffsetThreshold && self.scrollView.isDragging) {
                    self.state = YLPullToLoadMoreStateTriggered;
                }
            }
            else if(contentOffset.y < scrollOffsetThreshold  && self.state != YLPullToLoadMoreStateStopped)
                self.state = YLPullToLoadMoreStateStopped;
        }
        else {
            if(!self.scrollView.isDragging && self.state == YLPullToLoadMoreStateTriggered)
                self.state = YLPullToLoadMoreStateLoading;
            else if(contentOffset.y > scrollOffsetThreshold && self.state == YLPullToLoadMoreStateStopped && self.scrollView.isDragging)
                self.state = YLPullToLoadMoreStateTriggered;
            else if(contentOffset.y < scrollOffsetThreshold  && self.state != YLPullToLoadMoreStateStopped)
                self.state = YLPullToLoadMoreStateStopped;
        }
    }
}

#pragma mark - Getters

- (UILabel *)titleLabel {
    if(!_titleLabel) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 210, 20)];
        _titleLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:13];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.textColor = self.textColor;
        [self addSubview:_titleLabel];
    }
    return _titleLabel;
}

- (UIActivityIndicatorView *)activityIndicatorView {
    if(!_activityIndicatorView) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _activityIndicatorView.hidesWhenStopped = YES;
        [self addSubview:_activityIndicatorView];
    }
    return _activityIndicatorView;
}

- (UIActivityIndicatorViewStyle)activityIndicatorViewStyle {
    return self.activityIndicatorView.activityIndicatorViewStyle;
}

#pragma mark - Setters

- (void)setCustomView:(UIView *)view forState:(YLPullToLoadMoreState)state {
    id viewPlaceholder = view;
    
    if(!viewPlaceholder)
        viewPlaceholder = @"";
    
    if(state == YLPullToLoadMoreStateAll)
        [self.viewForState replaceObjectsInRange:NSMakeRange(0, 5) withObjectsFromArray:@[viewPlaceholder, viewPlaceholder, viewPlaceholder, viewPlaceholder, viewPlaceholder]];
    else
        [self.viewForState replaceObjectAtIndex:state withObject:viewPlaceholder];
    
    self.state = self.state;
}

- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)viewStyle {
    self.activityIndicatorView.activityIndicatorViewStyle = viewStyle;
}

#pragma mark -

- (void)startAnimating{
    self.state = YLPullToLoadMoreStateLoading;
}

- (void)stopAnimating {
    self.state = YLPullToLoadMoreStateStopped;
}

- (void)stopAnimatingWithNoMoreData {
    self.state = YLPullToLoadMoreStateNoMoreData;
}


- (void)setState:(YLPullToLoadMoreState)newState {
    
    if(_state == newState)
        return;
    
    YLPullToLoadMoreState previousState = _state;
    _previousState = previousState;
    _state = newState;
    [self setNeedsLayout];
    [self layoutIfNeeded];
    
    self.enabled = YES;
    switch (newState) {
        case YLPullToLoadMoreStateStopped:
            [self.activityIndicatorView stopAnimating];
            break;
            
        case YLPullToLoadMoreStatePreLoadTriggered:
            [self.activityIndicatorView startAnimating];
            break;
            
        case YLPullToLoadMoreStateTriggered:
            [self.activityIndicatorView startAnimating];
            break;
            
        case YLPullToLoadMoreStateLoading:
            [self.activityIndicatorView startAnimating];
            break;
            
        case YLPullToLoadMoreStateNoMoreData:{
            [self.activityIndicatorView stopAnimating];
            self.enabled = NO;
        }
            break;
            
        default:
            break;
    }
    
    if((previousState == YLPullToLoadMoreStatePreLoadTriggered || previousState == YLPullToLoadMoreStateTriggered)
       && newState == YLPullToLoadMoreStateLoading
       && self.pullToLoadMoreHandler
       && self.enabled){
        self.pullToLoadMoreHandler();
    }
    
}

@end
