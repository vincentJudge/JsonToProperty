//
//  SourceEditorCommand.m
//  JsonToPropertyExtension
//
//  Created by vincent on 2022/3/30.
//

#import "SourceEditorCommand.h"
#import <AppKit/AppKit.h>
#import "ESClassInfo.h"

#define ESRootClassName @"ESRootClass"

@interface SourceEditorCommand ()
@property (nonatomic, strong) XCSourceTextBuffer *buffer;
@property (nonatomic, copy) void(^completionHandler)(NSError * _Nullable nilOrError);
@end

@implementation SourceEditorCommand

- (void)performCommandWithInvocation:(XCSourceEditorCommandInvocation *)invocation completionHandler:(void (^)(NSError * _Nullable nilOrError))completionHandler
{
    self.completionHandler = completionHandler;
    self.buffer = invocation.buffer;
    self.isSwift = [self.buffer.contentUTI rangeOfString:@"swift"].length!=0;
    
    NSString *jsonString = @"";
    if ([invocation.commandIdentifier isEqualToString:@"JsonToProperty"]) {
        XCSourceTextRange *range = self.buffer.selections.firstObject;
        for (NSInteger i=range.start.line; i<=range.end.line; i++) {
            if (i<self.buffer.lines.count) {
                jsonString = [NSString stringWithFormat:@"%@%@",jsonString,self.buffer.lines[i]];
            }
        }
    } else {
        jsonString = [[NSPasteboard generalPasteboard] stringForType:NSStringPboardType];
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    id dicOrArray = [NSJSONSerialization JSONObjectWithData:jsonData
                                                    options:NSJSONReadingMutableContainers
                                                      error:&err];
    if (err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = err.localizedDescription;
            [alert addButtonWithTitle:@"OK"];
            alert.window.level = NSStatusWindowLevel;
            [alert.window makeKeyAndOrderFront:alert.window];
            if([alert runModal] == NSAlertFirstButtonReturn) {
                
            }
            self.completionHandler(nil);
        });
    } else {
        ESClassInfo *classInfo = [self dealClassNameWithJsonResult:dicOrArray];
        [self outputResult:classInfo];
        self.completionHandler(nil);
    }
}


- (ESClassInfo *)dealClassNameWithJsonResult:(id)result{
    __block ESClassInfo *classInfo = nil;
    //???????????????JSON???????????????
    if ([result isKindOfClass:[NSDictionary class]]) {

        //?????????????????????Root class ????????????????????????
        classInfo = [[ESClassInfo alloc] initWithClassNameKey:ESRootClassName ClassName:ESRootClassName classDic:result];
        classInfo.isSwift = self.isSwift;
        [self dealPropertyNameWithClassInfo:classInfo];
        
    }else if([result isKindOfClass:[NSArray class]]){
        NSDictionary *dic = [NSDictionary dictionaryWithObject:result forKey:@"<#ClassName#>"];
        classInfo = [[ESClassInfo alloc] initWithClassNameKey:ESRootClassName ClassName:ESRootClassName classDic:dic];
        classInfo.isSwift = self.isSwift;
        [self dealPropertyNameWithClassInfo:classInfo];
    }
    return classInfo;
}

- (ESClassInfo *)dealPropertyNameWithClassInfo:(ESClassInfo *)classInfo{
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:classInfo.classDic];
    for (NSString *key in dic) {
        //??????????????????NSDictionary??????NSArray
        id obj = dic[key];
        if ([obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSDictionary class]]) {
            if ([obj isKindOfClass:[NSArray class]]) {
                //May be 'NSString'???will crash
                if (!([[obj firstObject] isKindOfClass:[NSDictionary class]] || [[obj firstObject] isKindOfClass:[NSArray class]])) {
                    continue;
                }
            }
           
            NSString *childClassName = [key.capitalizedString stringByAppendingString:@"Model"];
            //????????????obj??? NSDictionary ?????? NSArray?????????????????????
            if ([obj isKindOfClass:[NSDictionary class]]) {
                ESClassInfo *childClassInfo = [[ESClassInfo alloc] initWithClassNameKey:key ClassName:childClassName classDic:obj];
                childClassInfo.isSwift = classInfo.isSwift;
                [self dealPropertyNameWithClassInfo:childClassInfo];
                //??????classInfo??????????????????class
                [classInfo.propertyClassDic setObject:childClassInfo forKey:key];
            }else if([obj isKindOfClass:[NSArray class]]){
                //????????? NSArray ?????????????????????????????????
                NSArray *array = obj;
                if (array.firstObject) {
                    NSObject *obj = [array firstObject];
                    //May be 'NSString'???will crash
                    if ([obj isKindOfClass:[NSDictionary class]]) {
                        ESClassInfo *childClassInfo = [[ESClassInfo alloc] initWithClassNameKey:key ClassName:childClassName classDic:(NSDictionary *)obj];
                        childClassInfo.isSwift = classInfo.isSwift;
                        [self dealPropertyNameWithClassInfo:childClassInfo];
                        //??????classInfo????????????????????? NSArray ????????????NSArray ??????????????????????????????class
                        [classInfo.propertyArrayDic setObject:childClassInfo forKey:key];
                    }
                }
            }
        }
    }
    return classInfo;
}

-(void)outputResult:(ESClassInfo*)info{
    ESClassInfo *classInfo = info;
    
    XCSourceTextRange *range = self.buffer.selections.firstObject;
    [self.buffer.lines removeObjectsInRange:NSMakeRange(range.start.line, range.end.line-range.start.line+1)];
    
    //????????????????????????
    [self.buffer.lines insertObject:classInfo.propertyContent atIndex:range.start.line];
    
    //??????????????????????????????????????????????????????
    [self.buffer.lines insertObject:classInfo.classInsertTextViewContentForH atIndex:self.buffer.lines.count];
    
    if (!info.isSwift) {
        //@class
        NSString *atClassContent = classInfo.atClassContent;
        NSInteger index = -1;
        for (int i=0; i<self.buffer.lines.count; i++) {
            NSString *str = self.buffer.lines[i];
            if ([str rangeOfString:@"@interface"].length>0) {
                index = i;
                break;
            }
        }
        if (index!=-1 && atClassContent.length>0) {
            [self.buffer.lines insertObject:[NSString stringWithFormat:@"\n%@\n",atClassContent] atIndex:index];
        }
    }
  
    XCSourceTextRange *selection = [[XCSourceTextRange alloc] initWithStart:XCSourceTextPositionMake(0, 0) end:XCSourceTextPositionMake(0, 0)];
    [self.buffer.selections removeAllObjects];
    [self.buffer.selections insertObject:selection atIndex:0];
}

@end
