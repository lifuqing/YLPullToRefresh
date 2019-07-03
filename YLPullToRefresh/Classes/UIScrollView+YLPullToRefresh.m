//
// UIScrollView+YLPullToRefresh.m
//
//  Created by lifuqing on 2019/5/21.
//  Copyright © 2019 Home. All rights reserved.
//
//

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import "UIScrollView+YLPullToRefresh.h"
#import <AudioToolbox/AudioToolbox.h>
#import "YLCircleActivityIndicatorView.h"
#import "UIScrollView+YLPullToLoadMore.h"

//fequal() and fequalzro() from http://stackoverflow.com/a/1614761/184130
#define fequal(a,b) (fabs((a) - (b)) < FLT_EPSILON)
#define fequalzero(a) (fabs(a) < FLT_EPSILON)

static CGFloat const YLPullToRefreshViewHeight = 60;

@interface YLPullToRefreshCircleLayer : CALayer

@property (nonatomic, strong) UIColor * ringBackgroundColor;
@property (nonatomic, strong) UIColor * ringFillColor;
@property (nonatomic, assign) CGFloat ringWidth;//default 1.0

- (void)startAnimating;
- (void)stopAnimating;

- (void)setProgress:(CGFloat)progress;

@end


@interface YLPullToRefreshArrow : UIView

@property (nonatomic, strong) UIColor *arrowColor;
@property (nonatomic, assign) CGFloat arrowLineWidth;//默认1

@end


@interface YLPullToRefreshView ()

@property (nonatomic, copy) void (^pullToRefreshActionHandler)(void);

@property (nonatomic, strong) YLPullToRefreshArrow *arrow;
@property (nonatomic, strong) YLPullToRefreshCircleLayer *circleLayer;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, readwrite) YLPullToRefreshState state;

@property (nonatomic, strong) NSMutableArray *titles;
@property (nonatomic, strong) NSMutableArray *subtitles;
@property (nonatomic, strong) NSMutableArray *viewForState;

@property (nonatomic) CFURLRef soundFileURLRef;
@property (nonatomic, readonly) SystemSoundID soundFileObject;

@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, readwrite) CGFloat originalTopInset;

@property (nonatomic, assign) BOOL wasTriggeredByUser;
@property (nonatomic, assign) BOOL showsPullToRefresh;
@property (nonatomic, assign) BOOL showsDateLabel;
@property(nonatomic, assign) BOOL isObserving;

- (void)resetScrollViewContentInset;
- (void)setScrollViewContentInsetForLoading;
- (void)setScrollViewContentInset:(UIEdgeInsets)insets;
- (void)rotateArrow:(float)degrees hide:(BOOL)hide;

@end



#pragma mark - UIScrollView (YLPullToRefresh)
#import <objc/runtime.h>

static char UIScrollViewPullToRefreshView;

@implementation UIScrollView (YLPullToRefresh)

@dynamic pullToRefreshView, showsPullToRefresh;

- (void)addPullToRefreshWithActionHandler:(void (^)(void))actionHandler {
    if(!self.pullToRefreshView) {
        CGFloat yOrigin = -YLPullToRefreshViewHeight;
        YLPullToRefreshView *view = [[YLPullToRefreshView alloc] initWithFrame:CGRectMake(0, yOrigin, self.bounds.size.width, YLPullToRefreshViewHeight)];
        view.pullToRefreshActionHandler = actionHandler;
        view.scrollView = self;
        [self addSubview:view];
        
        view.originalTopInset = self.contentInset.top;
        
        self.pullToRefreshView = view;
        self.showsPullToRefresh = YES;
    }
}

- (void)triggerPullToRefresh {
    self.pullToRefreshView.state = YLPullToRefreshStateTriggered;
    [self.pullToRefreshView startAnimating];
}

- (void)setPullToRefreshView:(YLPullToRefreshView *)pullToRefreshView {
    [self willChangeValueForKey:@"YLPullToRefreshView"];
    objc_setAssociatedObject(self, &UIScrollViewPullToRefreshView,
                             pullToRefreshView,
                             OBJC_ASSOCIATION_ASSIGN);
    [self didChangeValueForKey:@"YLPullToRefreshView"];
}

- (YLPullToRefreshView *)pullToRefreshView {
    return objc_getAssociatedObject(self, &UIScrollViewPullToRefreshView);
}

- (void)setShowsPullToRefresh:(BOOL)showsPullToRefresh {
    self.pullToRefreshView.hidden = !showsPullToRefresh;
    
    if(!showsPullToRefresh) {
        if (self.pullToRefreshView.isObserving) {
            [self removeObserver:self.pullToRefreshView forKeyPath:@"contentOffset"];
            [self removeObserver:self.pullToRefreshView forKeyPath:@"contentSize"];
            [self removeObserver:self.pullToRefreshView forKeyPath:@"frame"];
            [self.pullToRefreshView resetScrollViewContentInset];
            self.pullToRefreshView.isObserving = NO;
        }
    }
    else {
        if (!self.pullToRefreshView.isObserving) {
            [self addObserver:self.pullToRefreshView forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
            [self addObserver:self.pullToRefreshView forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
            [self addObserver:self.pullToRefreshView forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:nil];
            self.pullToRefreshView.isObserving = YES;
            
            CGFloat yOrigin = -YLPullToRefreshViewHeight;
            
            self.pullToRefreshView.frame = CGRectMake(0, yOrigin, self.bounds.size.width, YLPullToRefreshViewHeight);
        }
    }
}

- (BOOL)showsPullToRefresh {
    return !self.pullToRefreshView.hidden;
}

@end

#pragma mark - YLPullToRefresh
@implementation YLPullToRefreshView

// public properties
@synthesize pullToRefreshActionHandler, arrowColor, textColor, activityIndicatorViewColor, activityIndicatorViewStyle;

@synthesize state = _state;
@synthesize scrollView = _scrollView;
@synthesize showsPullToRefresh = _showsPullToRefresh;
@synthesize arrow = _arrow;
@synthesize activityIndicatorView = _activityIndicatorView;

@synthesize titleLabel = _titleLabel;


- (id)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        
        self.style = YLPullToRefreshStyleDefault;
        self.position = YLPullToRefreshArrowPositionDefault;
        self.activityStyle = YLPullToRefreshActivityStyleDefault;
        
        // default styling values
        if (self.activityStyle == YLPullToRefreshActivityStyleSystem) {
            self.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        }
        
        self.textColor = [UIColor darkGrayColor];
        self.arrowColor = [UIColor grayColor];
        self.arrowLineWidth = 1;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.state = YLPullToRefreshStateStopped;
        self.showsDateLabel = NO;
        
        self.titles = [NSMutableArray arrayWithObjects:@"轻轻下拉刷新数据",
                       @"放手吧我要刷新啦",
                       @"正在刷新...",
                       nil];
        
        self.subtitles = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", nil];
        self.viewForState = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", nil];
        self.wasTriggeredByUser = YES;
        
        self.refreshSound = YES;
        
        [self setRefreshSound];
    }
    
    return self;
}

- (void)dealloc {
    AudioServicesDisposeSystemSoundID(self.soundFileObject);
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (self.superview && newSuperview == nil) {
        //use self.superview, not self.scrollView. Why self.scrollView == nil here?
        UIScrollView *scrollView = (UIScrollView *)self.superview;
        if (scrollView.showsPullToRefresh) {
            if (self.isObserving) {
                //If enter this branch, it is the moment just before "YLPullToRefreshView's dealloc", so remove observer here
                [scrollView removeObserver:self forKeyPath:@"contentOffset"];
                [scrollView removeObserver:self forKeyPath:@"contentSize"];
                [scrollView removeObserver:self forKeyPath:@"frame"];
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
    self.subtitleLabel.hidden = hasCustomView;
    self.arrow.hidden = hasCustomView;
    self.circleLayer.hidden = hasCustomView;
    
    if(hasCustomView) {
        [self addSubview:customView];
        CGRect viewBounds = [customView bounds];
        CGPoint origin = CGPointMake(roundf((self.bounds.size.width-viewBounds.size.width)/2), roundf((self.bounds.size.height-viewBounds.size.height)/2));
        [customView setFrame:CGRectMake(origin.x, origin.y, viewBounds.size.width, viewBounds.size.height)];
    }
    else {
        switch (self.state) {
            case YLPullToRefreshStateAll:
            case YLPullToRefreshStateStopped:
                self.arrow.alpha = 1;
                [self.activityIndicatorView stopAnimating];
                [self rotateArrow:0 hide:NO];
                break;
                
            case YLPullToRefreshStateTriggered:
                [self rotateArrow:(self.style == YLPullToRefreshStyleDefault ? 0 : (float)M_PI) hide:NO];
                break;
                
            case YLPullToRefreshStateLoading:
                [self.activityIndicatorView startAnimating];
                [self rotateArrow:0 hide:YES];
                break;
        }
        
        CGFloat leftViewWidth = MAX(self.arrow.bounds.size.width,self.activityIndicatorView.bounds.size.width);
        
        CGFloat margin = 10;
        CGFloat marginY = 2;
        CGFloat labelMaxWidth = self.bounds.size.width - margin - leftViewWidth;
        
        self.titleLabel.text = [self.titles objectAtIndex:self.state];
        
        NSString *subtitle = [self.subtitles objectAtIndex:self.state];
        self.subtitleLabel.text = subtitle.length > 0 ? subtitle : nil;
        
        
        CGSize titleSize = [self.titleLabel.text boundingRectWithSize:CGSizeMake(labelMaxWidth,self.titleLabel.font.lineHeight) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: self.titleLabel.font} context:nil].size;
        
        
        CGSize subtitleSize = [self.subtitleLabel.text boundingRectWithSize:CGSizeMake(labelMaxWidth,self.subtitleLabel.font.lineHeight) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: self.subtitleLabel.font} context:nil].size;
        
        CGFloat maxLabelWidth = MAX(titleSize.width,subtitleSize.width);
        
        CGFloat totalMaxWidth;
        if (maxLabelWidth) {
            totalMaxWidth = leftViewWidth + margin + maxLabelWidth;
        } else {
            totalMaxWidth = leftViewWidth + maxLabelWidth;
        }
        
        CGFloat labelX = (self.bounds.size.width / 2) - (totalMaxWidth / 2) + leftViewWidth + margin;
        
        if(subtitleSize.height > 0){
            CGFloat totalHeight = titleSize.height + subtitleSize.height + marginY;
            CGFloat minY = (self.bounds.size.height / 2)  - (totalHeight / 2) - self.originalTopInset;
            
            CGFloat titleY = minY;
            self.titleLabel.frame = CGRectIntegral(CGRectMake(labelX, titleY, titleSize.width, titleSize.height));
            self.subtitleLabel.frame = CGRectIntegral(CGRectMake(labelX, titleY + titleSize.height + marginY, subtitleSize.width, subtitleSize.height));
        }else{
            CGFloat totalHeight = titleSize.height;
            CGFloat minY = (self.bounds.size.height / 2)  - (totalHeight / 2) - self.originalTopInset;
            
            CGFloat titleY = minY;
            self.titleLabel.frame = CGRectIntegral(CGRectMake(labelX, titleY, titleSize.width, titleSize.height));
            self.subtitleLabel.frame = CGRectIntegral(CGRectMake(labelX, titleY + titleSize.height + marginY, subtitleSize.width, subtitleSize.height));
        }
        
        CGFloat arrowX = (self.bounds.size.width / 2) - (totalMaxWidth / 2) + (leftViewWidth - self.arrow.bounds.size.width) / 2;
        if (self.position == YLPullToRefreshArrowPositionDefault) {
            if (self.arrow.frame.origin.x > 0) {
                arrowX = MIN(arrowX, self.arrow.frame.origin.x);
            }
        }
        self.arrow.frame = CGRectMake(arrowX,
                                      (self.bounds.size.height / 2) - (self.arrow.bounds.size.height / 2) - self.originalTopInset,
                                      self.arrow.bounds.size.width,
                                      self.arrow.bounds.size.height);
        self.activityIndicatorView.center = self.arrow.center;
        self.circleLayer.frame = self.arrow.frame;
    }
}

#pragma mark - Scroll View

- (void)resetScrollViewContentInset {
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    currentInsets.top = self.originalTopInset;
    [self setScrollViewContentInset:currentInsets];
}

- (void)setScrollViewContentInsetForLoading {
    CGFloat offset = MAX(self.scrollView.contentOffset.y * -1, 0);
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    currentInsets.top = MIN(offset, self.originalTopInset + self.bounds.size.height);
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
        
        CGFloat yOrigin = -YLPullToRefreshViewHeight;
        self.frame = CGRectMake(0, yOrigin, self.bounds.size.width, YLPullToRefreshViewHeight);
    }
    else if([keyPath isEqualToString:@"frame"])
        [self layoutSubviews];
    
}

- (void)scrollViewDidScroll:(CGPoint)contentOffset {
    if (contentOffset.y > 0) {
        return;
    }
    if(self.state != YLPullToRefreshStateLoading) {
        CGFloat scrollOffsetThreshold = self.frame.origin.y - self.originalTopInset;
        if(!self.scrollView.isDragging && self.state == YLPullToRefreshStateTriggered)
            self.state = YLPullToRefreshStateLoading;
        else if(contentOffset.y < scrollOffsetThreshold && self.scrollView.isDragging && self.state == YLPullToRefreshStateStopped)
            self.state = YLPullToRefreshStateTriggered;
        else if(contentOffset.y >= scrollOffsetThreshold && self.state != YLPullToRefreshStateStopped)
            self.state = YLPullToRefreshStateStopped;
    } else {
        CGFloat offset;
        UIEdgeInsets contentInset;
        offset = MAX(self.scrollView.contentOffset.y * -1, 0.0f);
        offset = MIN(offset, self.originalTopInset + self.bounds.size.height);
        contentInset = self.scrollView.contentInset;
        self.scrollView.contentInset = UIEdgeInsetsMake(offset, contentInset.left, contentInset.bottom, contentInset.right);
    }
    
    [self pullToRefreshViewScrollViewDidScroll:contentOffset];
}

- (void)pullToRefreshViewScrollViewDidScroll:(CGPoint)contentOffset {
    id customView = [self.viewForState objectAtIndex:self.state];
    BOOL hasCustomView = [customView isKindOfClass:[UIView class]];
    
    CGFloat scrollOffsetThreshold = self.frame.origin.y - self.originalTopInset;
    
    if (self.state == YLPullToRefreshStateStopped) {
        if (-contentOffset.y >= 0 && -contentOffset.y <= -scrollOffsetThreshold) {
            CGFloat progress = MIN(-contentOffset.y * 1.0, -scrollOffsetThreshold)/-scrollOffsetThreshold;
            [self.circleLayer setProgress:progress];
            if (hasCustomView && [customView respondsToSelector:@selector(pullToRefreshViewDidScrollWithProgress:)]) {
                [customView pullToRefreshViewDidScrollWithProgress:progress];
            }
        }
    }
    else if (self.state == YLPullToRefreshStateTriggered) {
        [self.circleLayer setProgress:1];
        if (hasCustomView && [customView respondsToSelector:@selector(pullToRefreshViewDidScrollWithProgress:)]) {
            [customView pullToRefreshViewDidScrollWithProgress:1];
        }
    }
}
#pragma mark - Getters

- (YLPullToRefreshArrow *)arrow {
    if(!_arrow) {
        _arrow = [[YLPullToRefreshArrow alloc]initWithFrame:CGRectMake(0, self.bounds.size.height-26, 26, 26)];
        _arrow.backgroundColor = [UIColor clearColor];
        [self addSubview:_arrow];
    }
    return _arrow;
}

- (UIActivityIndicatorView *)activityIndicatorView {
    if(!_activityIndicatorView) {
        if (self.activityStyle == YLPullToRefreshActivityStyleDefault) {
            _activityIndicatorView = (UIActivityIndicatorView *)[[YLCircleActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 26, 26)];
        }
        else {
            _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        }
        _activityIndicatorView.hidesWhenStopped = YES;
        [self addSubview:_activityIndicatorView];
    }
    return _activityIndicatorView;
}

- (UILabel *)titleLabel {
    if(!_titleLabel) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 210, 20)];
        _titleLabel.text = @"轻轻下拉刷新数据";
        _titleLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:13];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = textColor;
        [self addSubview:_titleLabel];
    }
    return _titleLabel;
}

- (UILabel *)subtitleLabel {
    if(!_subtitleLabel) {
        _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 210, 20)];
        _subtitleLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:11];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.textColor = textColor;
        [self addSubview:_subtitleLabel];
    }
    return _subtitleLabel;
}

- (UIColor *)arrowColor {
    return self.arrow.arrowColor;
}

- (UIColor *)textColor {
    return self.titleLabel.textColor;
}

- (UIColor *)activityIndicatorViewColor {
    return self.activityIndicatorView.color;
}

- (UIActivityIndicatorViewStyle)activityIndicatorViewStyle {
    return self.activityStyle == YLPullToRefreshActivityStyleSystem ? self.activityIndicatorView.activityIndicatorViewStyle : UIActivityIndicatorViewStyleGray;
}

- (YLPullToRefreshCircleLayer *)circleLayer {
    if (!_circleLayer) {
        _circleLayer = [[YLPullToRefreshCircleLayer alloc] init];
        _circleLayer.frame = self.bounds;
    }
    return _circleLayer;
}

#pragma mark - Setters

- (void)setArrowColor:(UIColor *)newArrowColor {
    self.arrow.arrowColor = newArrowColor;
    [self.arrow setNeedsDisplay];
    
    self.circleLayer.ringFillColor = newArrowColor;
    [self.circleLayer setNeedsDisplay];
    
    if (self.activityStyle == YLPullToRefreshActivityStyleDefault) {
        self.activityIndicatorView.tintColor = newArrowColor;
    }
}

- (void)setArrowLineWidth:(CGFloat)arrowLineWidth {
    _arrowLineWidth = arrowLineWidth;
    
    self.arrow.arrowLineWidth = arrowLineWidth;
    [self.arrow setNeedsDisplay];
    
    self.circleLayer.ringWidth = arrowLineWidth;
    [self.circleLayer setNeedsDisplay];
    
    if (self.activityStyle == YLPullToRefreshActivityStyleDefault) {
        ((YLCircleActivityIndicatorView *)self.activityIndicatorView).lineWidth = arrowLineWidth;
        [self.activityIndicatorView setNeedsDisplay];
    }
}

- (void)setTitle:(NSString *)title forState:(YLPullToRefreshState)state {
    if(!title)
        title = @"";
    
    if(state == YLPullToRefreshStateAll)
        [self.titles replaceObjectsInRange:NSMakeRange(0, 3) withObjectsFromArray:@[title, title, title]];
    else
        [self.titles replaceObjectAtIndex:state withObject:title];
    
    [self setNeedsLayout];
}

- (void)setSubtitle:(NSString *)subtitle forState:(YLPullToRefreshState)state {
    if(!subtitle)
        subtitle = @"";
    
    if(state == YLPullToRefreshStateAll)
        [self.subtitles replaceObjectsInRange:NSMakeRange(0, 3) withObjectsFromArray:@[subtitle, subtitle, subtitle]];
    else
        [self.subtitles replaceObjectAtIndex:state withObject:subtitle];
    
    [self setNeedsLayout];
}

- (void)setCustomView:(UIView *)view forState:(YLPullToRefreshState)state {
    id viewPlaceholder = view;
    
    if(!viewPlaceholder)
        viewPlaceholder = @"";
    
    if(state == YLPullToRefreshStateAll)
        [self.viewForState replaceObjectsInRange:NSMakeRange(0, 3) withObjectsFromArray:@[viewPlaceholder, viewPlaceholder, viewPlaceholder]];
    else
        [self.viewForState replaceObjectAtIndex:state withObject:viewPlaceholder];
    
    [self setNeedsLayout];
}

- (void)setTextColor:(UIColor *)newTextColor {
    textColor = newTextColor;
    self.titleLabel.textColor = newTextColor;
    self.subtitleLabel.textColor = newTextColor;
}

- (void)setActivityIndicatorViewColor:(UIColor *)color {
    self.activityIndicatorView.color = color;
}

- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)viewStyle {
    if (self.activityStyle == YLPullToRefreshActivityStyleSystem) {
        self.activityIndicatorView.activityIndicatorViewStyle = viewStyle;
    }
}

- (void)setStyle:(YLPullToRefreshStyle)style {
    _style = style;
    
    if (style == YLPullToRefreshStyleDefault) {
        if (![[self.layer sublayers] containsObject:_circleLayer]) {
            [self.layer addSublayer:self.circleLayer];
        }
    }
    else {
        [_circleLayer removeFromSuperlayer];
    }
}

- (void)setActivityStyle:(YLPullToRefreshActivityStyle)activityStyle {
    if (_activityStyle != activityStyle) {
        _activityStyle = activityStyle;
        [_activityIndicatorView removeFromSuperview];
        _activityIndicatorView = nil;
    }
}

#pragma mark -

- (void)startAnimating{
    if(fequalzero(self.scrollView.contentOffset.y)) {
        [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, -self.frame.size.height) animated:YES];
        self.wasTriggeredByUser = NO;
    }
    else
        self.wasTriggeredByUser = YES;
    
    self.state = YLPullToRefreshStateLoading;
}

- (void)stopAnimating {
    self.state = YLPullToRefreshStateStopped;
    
    if (self.refreshSound) {
        [self playSystemSound];
    }
    
    if(!self.wasTriggeredByUser)
        [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, -self.originalTopInset) animated:YES];
}

- (void)setState:(YLPullToRefreshState)newState {
    
    if(_state == newState)
        return;
    
    YLPullToRefreshState previousState = _state;
    _state = newState;
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
    
    switch (newState) {
        case YLPullToRefreshStateAll:
        case YLPullToRefreshStateStopped:
            [self resetScrollViewContentInset];
            break;
            
        case YLPullToRefreshStateTriggered:
            break;
            
        case YLPullToRefreshStateLoading:
            [self setScrollViewContentInsetForLoading];
            
            if(previousState == YLPullToRefreshStateTriggered && pullToRefreshActionHandler) {
                if (self.scrollView.pullToLoadMoreView) {
                    [self.scrollView.pullToLoadMoreView removeNoMoreData];
                }
                pullToRefreshActionHandler();
            }
            
            break;
    }
}

- (void)rotateArrow:(float)degrees hide:(BOOL)hide {
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.arrow.layer.transform = CATransform3DMakeRotation(degrees, 0, 0, 1);
        self.arrow.layer.opacity = !hide;
        if (self.style == YLPullToRefreshStyleDefault) {
            self.circleLayer.opacity = !hide;
        }
    } completion:^(BOOL finished) {
        if (hide && self.style == YLPullToRefreshStyleDefault) {
            [self.circleLayer stopAnimating];
        }
    }];
}

- (void)setRefreshSound {
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"YLPullToRefresh" ofType:@"bundle"];
    
    NSURL *tapSound = [[NSBundle bundleWithPath:bundlePath] URLForResource:@"pull_refresh" withExtension:@"caf"];
    
    // Store the URL as a CFURLRef instance
    self.soundFileURLRef = (__bridge CFURLRef)tapSound;
    
    // Create a system sound object representing the sound file.
    AudioServicesCreateSystemSoundID(self.soundFileURLRef, &_soundFileObject);
}

- (void)playSystemSound {
    AudioServicesPlaySystemSound(_soundFileObject);
}

@end


#pragma mark - YLPullToRefreshArrow

@implementation YLPullToRefreshArrow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.arrowLineWidth = 1;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    CGContextRef c = UIGraphicsGetCurrentContext();
    
    CGFloat bolderW = self.arrowLineWidth;
    CGFloat paddingT = 4;
    
    CGFloat arrowH = rect.size.height - 2*paddingT;
    CGFloat paddingL = (rect.size.width - 2 * ((arrowH/2.0)*3/4))/2.0;
    
    // 绘制箭杆部分
    CGContextMoveToPoint(c, (rect.size.width)/2.0, paddingT + bolderW);
    CGContextAddLineToPoint(c, (rect.size.width)/2.0, arrowH + bolderW);
    CGContextSetLineWidth(c, bolderW);
    CGContextSetStrokeColorWithColor(c, [self.arrowColor CGColor]);
    CGContextStrokePath(c);
    
    // 绘制箭头部分
    CGContextMoveToPoint(c, paddingL, arrowH/2.0 + 3);
    CGContextAddLineToPoint(c, (rect.size.width)/2.0, arrowH + bolderW);
    CGContextAddLineToPoint(c, rect.size.width - paddingL, arrowH/2.0 + 3);
    CGContextSetStrokeColorWithColor(c, [self.arrowColor CGColor]);
    CGContextStrokePath(c);
    CGContextClosePath(c);
    
    CGContextSaveGState(c);
    CGContextRestoreGState(c);
}

@end

@interface YLPullToRefreshCircleLayer()

@property (strong, nonatomic) CAShapeLayer * ringBackgroundLayer;
@property (strong, nonatomic) CAShapeLayer * ringShapeLayer;
@property (strong, nonatomic) UIBezierPath * bezierPath;

@end

@implementation YLPullToRefreshCircleLayer

- (instancetype)init{
    self = [super init];
    if (self) {
        _ringFillColor = [UIColor redColor];
        _ringBackgroundColor = [UIColor clearColor];
        _ringWidth = 1.f;
        
        [self addSublayer:self.ringBackgroundLayer];
        [self.ringBackgroundLayer addSublayer:self.ringShapeLayer];
    }
    return self;
}

- (void)startAnimating{
    
}

- (void)stopAnimating{
    self.ringShapeLayer.strokeEnd = 0.0;
    [self.ringShapeLayer removeAllAnimations];
}

- (void)setProgress:(CGFloat)progress{
    self.ringShapeLayer.strokeEnd = progress;
}

- (void)setRingFillColor:(UIColor *)ringFillColor{
    _ringFillColor = ringFillColor;
    self.ringShapeLayer.strokeColor = ringFillColor.CGColor;
}

- (void)setRingBackgroundColor:(UIColor *)ringBackgroundColor{
    _ringBackgroundColor = ringBackgroundColor;
    self.ringBackgroundLayer.strokeColor = ringBackgroundColor.CGColor;
}

- (void)setRingWidth:(CGFloat)ringWidth {
    _ringWidth = ringWidth;
    _ringBackgroundLayer.lineWidth = _ringWidth;
    _ringShapeLayer.lineWidth = _ringWidth;
}

- (void)layoutSublayers{
    [super layoutSublayers];
    
    self.ringBackgroundLayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    self.ringBackgroundLayer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    
    self.ringShapeLayer.frame = self.ringBackgroundLayer.bounds;
    self.ringShapeLayer.position = CGPointMake(CGRectGetMidX(self.ringBackgroundLayer.bounds), CGRectGetMidY(self.ringBackgroundLayer.bounds));
    
    self.bezierPath = [UIBezierPath bezierPathWithRoundedRect:self.ringShapeLayer.bounds cornerRadius:self.ringShapeLayer.frame.size.width/2.];
    
    self.ringBackgroundLayer.path = self.bezierPath.CGPath;
    self.ringShapeLayer.path = self.bezierPath.CGPath;
}

- (CAShapeLayer *)ringBackgroundLayer{
    if (!_ringBackgroundLayer) {
        _ringBackgroundLayer = [CAShapeLayer layer];
        _ringBackgroundLayer.lineWidth = _ringWidth;
        _ringBackgroundLayer.lineCap = kCALineCapRound;
        _ringBackgroundLayer.backgroundColor = [UIColor clearColor].CGColor;
        _ringBackgroundLayer.fillColor = [UIColor clearColor].CGColor;
        _ringBackgroundLayer.strokeColor = self.ringBackgroundColor.CGColor;
    }
    return _ringBackgroundLayer;
}

- (CAShapeLayer *)ringShapeLayer{
    if (!_ringShapeLayer) {
        _ringShapeLayer = [CAShapeLayer layer];
        _ringShapeLayer.lineWidth = _ringWidth;
        _ringShapeLayer.lineCap = kCALineCapRound;
        _ringShapeLayer.backgroundColor = [UIColor clearColor].CGColor;
        _ringShapeLayer.fillColor = [UIColor clearColor].CGColor;
        _ringShapeLayer.strokeColor = self.ringFillColor.CGColor;
        _ringShapeLayer.strokeEnd = 0;
    }
    return _ringShapeLayer;
}

@end
