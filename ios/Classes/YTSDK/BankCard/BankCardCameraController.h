//
//  BankCardCameraController.h
//  SBankCardDemo
//
//  Created by ocrgroup on 2017/9/27.
//  Copyright © 2017年 ocrgroup. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SBankCardInfo;
typedef enum : NSUInteger {
    kAudioDirectionHorizontal,
    kAudioDirectionVertical,
} BankCardAudioDirection;



@protocol CameraDelegate <NSObject>

@required
//银行卡初始化结果，判断核心是否初始化成功
- (void)initBankCardWithResult:(int)nInit;
- (void)getBankCardInfo:(NSDictionary *)bankCardInfo;
@optional

@end


@interface BankCardCameraController : UIViewController

@property (assign, nonatomic) id<CameraDelegate>delegate;
@property(strong, nonatomic) UIImage *resultImg;
@property (copy, nonatomic) NSString *nsUserID; //授权码
@property (copy, nonatomic) NSString *nsNo; //识别结果


/**
 自定义init方法

 @param authorizationCode 授权文件名
 
 */
//- (instancetype)initWithAuthorizationCode:(NSString *)authorizationCode;

@end
