//
//  ViewController.m
//  objcRun
//
//  Created by Eric on 2018/2/28.
//  Copyright © 2018年 Eric. All rights reserved.
//

#import "ViewController.h"
#import "WTMessage.h"
#import "NSObject+KVO.h"

#define fuc 1

@interface ViewController ()
@property (nonatomic, strong) WTMessage * message;
@end

@implementation ViewController

- (void)dealloc{
    [self.message wt_removeObserver:self observerigkey:@"name"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.message = [[WTMessage alloc] init];
    self.message.name = @"sell";
    
    ///< 带有Block回调的观察者模式
#if fuc
    [self.message wt_addObserver:self observeringKey:@"name" observerBlock:^(id observerObject, NSString *observerkey, id oldValue, id newValue) {
        
    }];
#else
    ///< 模拟苹果底层的KVO实现
    [self.message wt_addObserver:self Observeringkey:@"name"];
#endif

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.message.name = @"hello world";
    });
    
    // Do any additional setup after loading the view, typically from a nib.
}
#if !fuc
- (void)wt_Observer:(id)observer ObserveringKey:(NSString *)key oldValue:(id)oldValue newValue:(id)newValue{
    
}
#endif

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
