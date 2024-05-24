//
//  FDEUtils.h
//  Example
//
//  Created by 薛权 on 2024/5/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FDEVoiceModel;
@interface FDEUtils : NSObject

+ (NSArray<FDEVoiceModel *> *)getVoiceListData;

@end

NS_ASSUME_NONNULL_END
