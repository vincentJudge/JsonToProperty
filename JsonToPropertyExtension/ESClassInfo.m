//
//  ESClassInfo.m
//  JsonToPropertyExtension
//
//  Created by vincent on 2022/3/30.
//

#import "ESClassInfo.h"
#import "ESJsonFormatManager.h"

@implementation ESClassInfo

- (instancetype)initWithClassNameKey:(NSString *)classNameKey ClassName:(NSString *)className classDic:(NSDictionary *)classDic
{
    self = [super init];
    if (self) {
        self.classNameKey = classNameKey;
        self.className = className;
        self.classDic = classDic;
    }
    return self;
}

- (NSMutableDictionary *)propertyClassDic{
    if (!_propertyClassDic) {
        _propertyClassDic = [NSMutableDictionary dictionary];
    }
    return _propertyClassDic;
}

- (NSMutableDictionary *)propertyArrayDic{
    if (!_propertyArrayDic) {
        _propertyArrayDic = [NSMutableDictionary dictionary];
    }
    return _propertyArrayDic;
}

- (NSArray *)atClassArray{
    NSMutableArray *result = [NSMutableArray array];
    [self.propertyClassDic enumerateKeysAndObjectsUsingBlock:^(id key, ESClassInfo *classInfo, BOOL *stop) {
        [result addObject:classInfo];
        [result addObjectsFromArray:classInfo.atClassArray];
    }];
    
    [self.propertyArrayDic enumerateKeysAndObjectsUsingBlock:^(id key, ESClassInfo *classInfo, BOOL *stop) {
//        if ([ESJsonFormatSetting defaultSetting].useGeneric) {
            [result addObject:classInfo];
//        }
        [result addObjectsFromArray:classInfo.atClassArray];
    }];
    
    return [result copy];
}

- (NSString *)atClassContent{
    NSArray *atClassArray = self.atClassArray;
    if (atClassArray.count==0) {
        return @"";
    }
    
    NSMutableArray *array = [NSMutableArray arrayWithArray:atClassArray];
    
    NSMutableString *resultStr = [NSMutableString stringWithFormat:@"@class "];
    for (ESClassInfo *classInfo in array) {
        [resultStr appendFormat:@"%@,",classInfo.className];
    }

    if ([resultStr hasSuffix:@","]) {
        resultStr = [NSMutableString stringWithString:[resultStr substringToIndex:resultStr.length-1]];
    }
    [resultStr appendString:@";"];
    return resultStr;
}

- (NSString *)propertyContent{
    return [ESJsonFormatManager parsePropertyContentWithClassInfo:self];
}

- (NSString *)classContentForH{
    return [ESJsonFormatManager parseClassHeaderContentWithClassInfo:self];
}

- (NSString *)classInsertTextViewContentForH{
    NSMutableString *result = [NSMutableString stringWithFormat:@""];
    for (NSString *key in self.propertyClassDic) {
        ESClassInfo *classInfo = self.propertyClassDic[key];
        [result appendFormat:@"\n%@\n",classInfo.classContentForH];
        [result appendString:classInfo.classInsertTextViewContentForH];
    }
    
    for (NSString *key in self.propertyArrayDic) {
        ESClassInfo *classInfo = self.propertyArrayDic[key];
        [result appendFormat:@"\n%@\n",classInfo.classContentForH];
        [result appendString:classInfo.classInsertTextViewContentForH];
    }
    return result;
}

@end
