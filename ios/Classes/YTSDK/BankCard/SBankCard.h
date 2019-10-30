//
//  SBankCard.h
//  SBankCard
//
//  Created by ocrgroup on 15/11/24.
//  Copyright © 2015年 ocrgroup. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SBankCard : NSObject

/** 银行卡号 */
@property (nonatomic, copy) NSString * nsNo;
/** 银行卡号图像（400*70） */
@property (nonatomic, strong) UIImage * resultImg;
/** 银行卡全图 */
@property (nonatomic, strong) UIImage * bankCardImg;
/** 有效日期 */
@property (nonatomic, copy) NSString * nsValidThru;
/** 授权截止日期 */
@property (nonatomic, copy) NSString * nsEndTime;
/** SDK版本号 */
@property (nonatomic, copy) NSString * sdkVersion;

/**
 初始化核心

 @param nsUserID 授权码/授权文件名
 @param nsReserve 传入nil即可
 @return 初始化结果 0-成功 其他返回值请参考开发文档
 */
- (int)initSBankCard:(NSString *)nsUserID nsReserve:(NSString *)nsReserve;

/**
 设置检测范围

 @param left 距离左侧的距离
 @param top 距离顶部的距离
 @param right 距离左侧的距离 + 宽度
 @param bottom 距离顶部的距离 + 高度
 */
- (void)setRegionWithLeft:(int)left Top:(int)top Right:(int)right Bottom:(int)bottom;

/**
 视频流识别

 @param buffer 缓冲区
 @param width buffer宽度
 @param height buffer高度
 @return 识别结果 0为识别成功
 */
- (int)recognizeSBankCard:(UInt8 *)buffer Width:(int)width Height:(int)height;

/**
 相册导入识别 / 拍照识别

 @param image 要识别的图像
 @return 识别结果 0为识别成功
 */
- (int)recognizeSBankCardImage:(UIImage *)image;

/**
 释放核心
 
 @return 0为释放成功
 */
- (int)freeSBankCard;

/**
 设置识别类型(视频流识别方式使用)

 @param type 0-横屏 1-竖屏
 */
- (void)setRecognizeType:(int)type;

@end
