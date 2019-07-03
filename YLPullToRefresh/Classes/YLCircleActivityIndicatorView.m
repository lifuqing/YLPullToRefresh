//
//  YLCircleActivityIndicatorView.m
//
//  Created by lifuqing on 2019/5/21.
//  Copyright © 2019 Home. All rights reserved.
//

#import "YLCircleActivityIndicatorView.h"
#import <QuartzCore/QuartzCore.h>

NSString *const kYLCircleActivityIndicatorViewSpinAnimationKey = @"YLCircleActivityIndicatorViewSpinAnimationKey";

@interface YLCircleActivityIndicatorView ()
@property (nonatomic, assign) BOOL animating;

@end
@implementation YLCircleActivityIndicatorView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

+ (Class)layerClass {
    return CAShapeLayer.class;
}

- (CAShapeLayer *)shapeLayer {
    return (CAShapeLayer *)self.layer;
}

- (void)commonInit {
    self.lineWidth = 1;
    
    self.hidesWhenStopped = YES;
    
    self.layer.borderWidth = 0;
    self.shapeLayer.lineWidth = self.lineWidth;
    self.shapeLayer.fillColor = UIColor.clearColor.CGColor;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGRect frame = self.frame;
    if (frame.size.width != frame.size.height) {
        // Ensure that we have a square frame
        CGFloat s = MAX(frame.size.width, frame.size.height);
        frame.size.width = s;
        frame.size.height = s;
        self.frame = frame;
    }
    
    self.shapeLayer.path = [self layoutPath].CGPath;
}

- (UIBezierPath *)layoutPath {
    const double TWO_M_PI = 2.0 * M_PI;
    double startAngle = 0.75 * TWO_M_PI;
    double endAngle = startAngle + TWO_M_PI * 0.9;
    
    CGFloat width = self.bounds.size.width;
    return [UIBezierPath bezierPathWithArcCenter:CGPointMake(width / 2.0f, width / 2.0f)
                                          radius:width / 2.2f
                                      startAngle:startAngle
                                        endAngle:endAngle
                                       clockwise:YES];
}

- (void)setLineWidth:(CGFloat)lineWidth {
    _lineWidth = lineWidth;
    self.shapeLayer.lineWidth = lineWidth;
}

#pragma mark - Hook tintColor

- (void)tintColorDidChange {
    [super tintColorDidChange];
    self.shapeLayer.strokeColor = self.tintColor.CGColor;
}

#pragma mark - Control animation

- (void)startAnimating {
    if (!_animating) {
        _animating = YES;
        
        CABasicAnimation *spinAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
        spinAnimation.toValue = @(1 * 2 * M_PI);
        spinAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        spinAnimation.duration = 1.0;
        spinAnimation.repeatCount = INFINITY;
        [self.layer addAnimation:spinAnimation forKey:kYLCircleActivityIndicatorViewSpinAnimationKey];
        
        if (self.hidesWhenStopped) {
            self.hidden = NO;
        }
    }
}

- (void)stopAnimating {
    _animating = NO;
    
    [self.layer removeAnimationForKey:kYLCircleActivityIndicatorViewSpinAnimationKey];
    
    if (self.hidesWhenStopped) {
        self.hidden = YES;
    }
}

- (BOOL)isAnimating {
    return _animating;
}

@end
