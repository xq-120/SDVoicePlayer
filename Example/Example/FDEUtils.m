//
//  FDEUtils.m
//  Example
//
//  Created by 薛权 on 2024/5/24.
//

#import "FDEUtils.h"
#import "Example-Swift.h"
#import <YYModel.h>
@implementation FDEUtils

+ (NSArray *)getVoiceListData {
    NSData *jsonData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"voiceList" ofType:@"json"]];
    NSDictionary *listDict = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
    NSArray *list = listDict[@"list"];
    NSArray *messages = [NSArray yy_modelArrayWithClass:FDEVoiceModel.class json:list];
    for (FDEVoiceModel *item in messages) {
        item.content = @"君不见黄河之水天上来，奔流到海不复回。君不见高堂明镜悲白发，朝如青丝暮成雪。人生得意须尽欢，莫使金樽空对月。";
    }
    return messages;
}

@end
