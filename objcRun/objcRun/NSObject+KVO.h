//
//  NSObject+KVO.h
//  objcRun
//
//  Created by Eric on 2018/3/4.
//  Copyright © 2018年 Eric. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^WTObservingBlock)(id observerObject,NSString * observerkey,id oldValue,id newValue);

@interface NSObject (KVO)

/**
 带有block回调的添加观察者

 @param observer 观察者
 @param key 将要观察的key
 @param block block回调
 */
- (void)wt_addObserver:(id)observer
        observeringKey:(NSString *)key
         observerBlock:(WTObservingBlock)block;

/**
 添加观察者

 @param observer 观察者
 @param key 将要观察的key
 */
- (void)wt_addObserver:(id)observer
        Observeringkey:(NSString *)key;

/**
 移除观察者

 @param observer 观察者
 @param key 将要观察的key
 */
- (void)wt_removeObserver:(id)observer
            observerigkey:(NSString *)key;

@end


@interface NSObject (NSObserver)

/**
 接收观察者

 @param observer 观察者
 @param key 观察者的key
 @param oldValue 旧值
 @param newValue 新值
 */
- (void)wt_Observer:(id)observer
     ObserveringKey:(NSString *)key
           oldValue:(id)oldValue
           newValue:(id)newValue;

@end
