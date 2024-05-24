//
//  ZAELabel.h
//  Syachat
//
//  Created by tommy on 2023/8/1.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, ZAEGradientType) {
    ZAEGradientTypeFromTopToDown, //(0.5, 0) -> (0.5, 1)
    ZAEGradientTypeFromDownToTop, //(0.5, 1) -> (0.5, 0)
    ZAEGradientTypeFromLeftToRight, //(0, 0.5) -> (1, 0.5)
    ZAEGradientTypeFromRightToLeft, //(1, 0.5) -> (0, 0.5)
    
    ZAEGradientTypeFromLeftTopToRightDown, //(0, 0) -> (1, 1)
    ZAEGradientTypeFromRightDownToLeftTop, //(1, 1) -> (0, 0)
    ZAEGradientTypeFromLeftDownToRightTop, //(0, 1) -> (1, 0)
    ZAEGradientTypeFromRightTopToLeftDown, //(1, 0) -> (0, 1)
};

@class ZAELabel;

@protocol ZAELabelDelegate <NSObject>

@optional
- (NSString *)pasteTextForLabel:(ZAELabel *)label;

@end

@interface ZAELabel : UILabel

@property (nonatomic, assign) UIEdgeInsets padding; //设置内间距

@property (nonatomic, weak) id<ZAELabelDelegate> delegate;

/** 默认ZAEGradientTypeFromLeftToRight. */
@property (nonatomic, assign) ZAEGradientType gradientType;

/** 默认nil.没有渐变背景色 */
@property (nonatomic, copy) NSArray<UIColor *> *gradientColors;

@end
