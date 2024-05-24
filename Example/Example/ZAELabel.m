//
//  ZAELabel.m
//  Syachat
//
//  Created by tommy on 2023/8/1.
//

#import "ZAELabel.h"

@interface ZAELabel ()

@end

@implementation ZAELabel

//绑定事件
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _gradientType = ZAEGradientTypeFromLeftToRight;
        [self attachTapHandler];
    }
    return self;
    
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    [self attachTapHandler];
}

// 可以响应的方法
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    return (action == @selector(copy:));
}

//针对于响应方法的实现
- (void)copy:(id)sender
{
    UIPasteboard *pboard = [UIPasteboard generalPasteboard];
    NSString *pasteText = self.text;
    if (self.delegate && [self.delegate respondsToSelector:@selector(pasteTextForLabel:)]) {
        pasteText = [self.delegate pasteTextForLabel:self];
    }
    pboard.string = pasteText;
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

//UILabel默认是不接收事件的，我们需要自己添加touch事件
-(void)attachTapHandler {
    UILongPressGestureRecognizer *touch = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self addGestureRecognizer:touch];
}

-(void)handleTap:(UIGestureRecognizer*) recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self becomeFirstResponder];
        [[UIMenuController sharedMenuController] setTargetRect:self.frame inView:self.superview];
        [[UIMenuController sharedMenuController] setMenuVisible:YES animated: YES];
    }
}

- (void)drawTextInRect:(CGRect)rect
{
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.padding)];
}

- (CGSize)intrinsicContentSize
{
    CGSize size = [super intrinsicContentSize];
    CGFloat width = size.width + self.padding.left + self.padding.right;
    CGFloat height = size.height + self.padding.top + self.padding.bottom;
    return CGSizeMake(width, height);
}

- (CGSize)sizeThatFits:(CGSize)size
{
    CGSize rs = self.intrinsicContentSize;
    return rs;
}

- (void)setGradientType:(ZAEGradientType)gradientType
{
    if (_gradientType == gradientType) {
        return;
    }
    
    _gradientType = gradientType;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    if (self.gradientColors.count == 0) {
        [super drawRect: rect];
        return;
    }
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:[self.gradientColors count]];
    [self.gradientColors enumerateObjectsUsingBlock:^(UIColor *obj, NSUInteger idx, BOOL *stop) {
        [colors addObject:(__bridge id)[obj CGColor]];
    }];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    //这里似乎不需要进行坐标系转换。
//    CGContextScaleCTM(context, 1.0, -1.0);
//    CGContextTranslateCTM(context, 0, -rect.size.height);
    
    CGFloat locations[] = {0.0, 1.0};
    CGGradientRef gradient = CGGradientCreateWithColors(NULL, (__bridge CFArrayRef)colors, locations);
    
    CGPoint startPoint = CGPointMake(CGRectGetMinX(rect), CGRectGetMidY(rect));
    CGPoint endPoint = CGPointMake(CGRectGetMaxX(rect), CGRectGetMidY(rect));
    switch (self.gradientType) {
        case ZAEGradientTypeFromTopToDown: {
            startPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect));
            endPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect));
            break;
        }
        case ZAEGradientTypeFromDownToTop: {
            startPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect));
            endPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect));
            break;
        }
        case ZAEGradientTypeFromLeftToRight: {
            startPoint = CGPointMake(CGRectGetMinX(rect), CGRectGetMidY(rect));
            endPoint = CGPointMake(CGRectGetMaxX(rect), CGRectGetMidY(rect));
            break;
        }
        case ZAEGradientTypeFromRightToLeft: {
            startPoint = CGPointMake(CGRectGetMaxX(rect), CGRectGetMidY(rect));
            endPoint = CGPointMake(CGRectGetMinX(rect), CGRectGetMidY(rect));
            break;
        }
        case ZAEGradientTypeFromLeftTopToRightDown: {
            startPoint = CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect));
            endPoint = CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect));
            break;
        }
        case ZAEGradientTypeFromRightDownToLeftTop: {
            startPoint = CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect));
            endPoint = CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect));
            break;
        }
        case ZAEGradientTypeFromLeftDownToRightTop: {
            startPoint = CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect));
            endPoint = CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect));
            break;
        }
        case ZAEGradientTypeFromRightTopToLeftDown: {
            startPoint = CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect));
            endPoint = CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect));
            break;
        }
        default:
            break;
    }
    
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint,
                                kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    
    CGGradientRelease(gradient);
    CGContextRestoreGState(context);
    
    [super drawRect:rect];
}

@end
