//
//  SBankCardInfo.h
//  SBankCardInfo
//
//  Created by ocrgroup on 16/5/12.
//  Copyright © 2016年 ocrgroup. All rights reserved.
//


#import <UIKit/UIKit.h>

@interface SBankCardInfo : NSObject

//识别结果

/** 开户银行名称 */
@property(copy, nonatomic) NSString *nsBankName; //开户行名称
/** 卡名称 */
@property(copy, nonatomic) NSString *nsCardName; //卡名称
/** 银行代码 */
@property(copy, nonatomic) NSString *nsBankCode; //银行代码
/** 卡类型 */
@property(copy, nonatomic) NSString *nsCardType; //卡类型


/**
 初始化核心
 
 @param nsUserID 授权码/授权文件名
 @param nsReserve 传入nil即可
 @return 初始化结果 0-成功 其他返回值请参考开发文档
 */
-(int) initSBankCardInfo;

/**
 获取卡号信息

 @param nsBankCardNo 银行卡号
 @return 是否获取成功
 */
-(int) getSBankCardInfo:(NSString *)nsBankCardNo;

/**
 释放核心
 */
-(void) freeSBankCardInfo;

@end
