//
//  NSObject+KVO.m
//  objcRun
//
//  Created by Eric on 2018/3/4.
//  Copyright © 2018年 Eric. All rights reserved.
//

#import "NSObject+KVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

static NSString * const kWTKVOClassPrefix = @"NSKVONotifing_";
static NSString * const kWTKVOAssoctedObservers = @"NSKVOAssoctedObservers";

@interface WTObservationInfo : NSObject

@property (nonatomic, weak) id observer;

@property (nonatomic, copy) NSString * key;

@property (nonatomic, copy) WTObservingBlock block;

@end


@implementation WTObservationInfo

- (instancetype)initWithObserver:(NSObject *)observer
                             key:(NSString *)key
                   observerBlock:(WTObservingBlock)block{
    if (self = [super init]) {
        _observer = observer;
        _key = [key copy];
        block? (_block = [block copy]) : nil;
    }
    return self;
}

@end


/**
 根据key,获取setter方法名
 */
static inline NSString * getterForSetter(NSString *setter){
    if (setter.length <=0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) {
        return nil;
    }
    
    NSRange range = NSMakeRange(3, setter.length-4);
    
    NSString * key = [setter substringWithRange:range];
    
    NSString *fristLetter = [[key substringToIndex:1] lowercaseString];
    
    key = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:fristLetter];
    
    return key;
}
/**
 根据key获取getter方法名
 */
static inline NSString * setterForGetter(NSString *getter){
    if (getter.length <=0) {
        return nil;
    }
    NSString *firstLetter = [[getter substringToIndex:1] uppercaseString];
    
    NSString * remainingLetters = [getter substringFromIndex:1];
    
    NSString * setter = [NSString stringWithFormat:@"set%@%@:",firstLetter,remainingLetters];
    
    return setter;
}
/**
 重写NSKVONotifity_Obj的setter方法 _cmd当前方法的一个SEL指针
 */
static inline void kvo_setter(id self,SEL _cmd,id newValue)
{
    NSString * setterName = NSStringFromSelector(_cmd);
    
    NSString * getterName = getterForSetter(setterName);
    
    if (!getterName) {
        NSString * reason = [NSString stringWithFormat:@"Object %@ does not have setter for key %@",self,setterName];
        
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        return;
    }
    
    id oldValue = [self valueForKey:getterName];
    
    struct objc_super superClass = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    void (*objc_msgSendSuperCasted)(void *,SEL,id) = (void *)objc_msgSendSuper;
    ///< 发送一条消息给父类
    objc_msgSendSuperCasted(&superClass,_cmd,newValue);
    
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(kWTKVOAssoctedObservers));
    
    for (WTObservationInfo *info in observers) {
        if ([info.key isEqualToString:getterName]) {
            
            if (info.block) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    info.block(self, getterName, oldValue, newValue);
                });
            }else{
                id observer = info.observer;
                
                Class superClass = class_getSuperclass(object_getClass(self));
                
                [observer wt_Observer:superClass ObserveringKey:getterName oldValue:oldValue newValue:newValue];
            }
        }
    }
}

/**
 获取父类的方法
 */
static inline Class kvo_class(id self,SEL _cmd){
    return class_getSuperclass(object_getClass(self));
}

@implementation NSObject (KVO)

- (void)wt_addObserver:(id)observer
        observeringKey:(NSString *)key
         observerBlock:(WTObservingBlock)block
{
    
    SEL setterSelector = NSSelectorFromString(setterForGetter(key));
    
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    
    if (!setterMethod) {
        NSString * reason = [NSString stringWithFormat:@"Object %@ does not have setter for key %@",self,key];
        
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        return;
    }
    
    Class clazz = object_getClass(self);
    
    NSString * className = NSStringFromClass(clazz);
    
    if (![className hasPrefix:kWTKVOClassPrefix]) {
        clazz = [self makeKvoClassWithOriginalClassName:className];
        ///< 将Obj的指针指向派生出来的NSKVONotifing_Obj,地址指针重定向
        object_setClass(self, clazz);
    }
    
    if (![self hasSeletor:setterSelector]) {
        
        const char *types = method_getTypeEncoding(setterMethod);
        
        class_addMethod(clazz, setterSelector, (IMP)kvo_setter, types);
    }
        
    WTObservationInfo * info = [[WTObservationInfo alloc] initWithObserver:observer key:key observerBlock:block];
    ///< 为给定的键返回与给定对象关联的值。
    NSMutableArray * observers = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kWTKVOAssoctedObservers));
    
    if (!observers) {
        observers = [NSMutableArray array];
        /// 为给定的键返回与给定对象关联的值。将kWTKVOAssocatedObservers和ObserVers做关联
        objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(kWTKVOAssoctedObservers), observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observers addObject:info];
}

- (void)wt_addObserver:(id)observer
        Observeringkey:(NSString *)key
{
    SEL setterSelector = NSSelectorFromString(setterForGetter(key));
    
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    
    if (!setterMethod) {
        NSString * reason = [NSString stringWithFormat:@"Object %@ does not have setter for key %@",self,key];
        
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        return;
    }
    
    Class clazz = object_getClass(self);
    
    NSString * className = NSStringFromClass(clazz);
    
    if (![className hasPrefix:kWTKVOClassPrefix]) {
        clazz = [self makeKvoClassWithOriginalClassName:className];
        ///< 将Obj的指针指向派生出来的NSKVONotifing_Obj,地址指针重定向
        object_setClass(self, clazz);
    }
    
    if (![self hasSeletor:setterSelector]) {
        
        const char *types = method_getTypeEncoding(setterMethod);
        
        class_addMethod(clazz, setterSelector, (IMP)kvo_setter, types);
    }
    
    WTObservationInfo * info = [[WTObservationInfo alloc] initWithObserver:observer key:key observerBlock:nil];
    ///< 为给定的键返回与给定对象关联的值。
    NSMutableArray * observers = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kWTKVOAssoctedObservers));
    
    if (!observers) {
        observers = [NSMutableArray array];
        /// 为给定的键返回与给定对象关联的值。将kWTKVOAssocatedObservers和ObserVers做关联
        objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(kWTKVOAssoctedObservers), observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observers addObject:info];
}

- (void)wt_removeObserver:(id)observer observerigkey:(NSString *)key{
    
    NSMutableArray * observers = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(kWTKVOAssoctedObservers));
    
    WTObservationInfo *removeInfo;
    for (WTObservationInfo * info in observers) {
        if (info.observer == observer && [info.key isEqualToString:key]) {
            removeInfo = info;
            break;
        }
    }
    [observers removeObject:removeInfo];
}

- (Class)makeKvoClassWithOriginalClassName:(NSString *)OriginalClassName
{
    ///< 模拟苹果底层自己的实现，生成一个NSKVONotifing_obj类
    NSString * kvoClassName = [kWTKVOClassPrefix stringByAppendingString:OriginalClassName];
    ///获取NSKVONotifing_obj,然后判断是否存在
    Class class = NSClassFromString(kvoClassName);
    if (class) {
        return class;
    }
    ///< 返回一个类
    Class originalClass = object_getClass(self);
    ///< 新建一个类名，继承自原类
    Class kvoClass = objc_allocateClassPair(originalClass, kvoClassName.UTF8String, 0);
    ///< 获取原类的Class方法
    Method classMethod = class_getInstanceMethod(originalClass, @selector(class));
    /// 为具有给定名称和实现的类添加新方法。
    class_addMethod(kvoClass, @selector(class), (IMP)kvo_class, method_getTypeEncoding(classMethod));
    /// 注册一个新类
    objc_registerClassPair(kvoClass);
    
    return kvoClass;
}

- (BOOL)hasSeletor:(SEL)selector {
    Class class = object_getClass(self);
    
    unsigned int methodCount = 0;
    
    Method * methodList = class_copyMethodList(class, &methodCount);
    
    for (unsigned int i = 0; i < methodCount;i++) {
        SEL thisSelector = method_getName(methodList[i]);
        if (thisSelector == selector) {
            return YES;
        }
    }
    free(methodList);
    
    return NO;
}

@end

@implementation NSObject (NSObserver)

- (void)wt_Observer:(id)observer
     ObserveringKey:(NSString *)key
           oldValue:(id)oldValue
           newValue:(id)newValue{
    
}

@end

