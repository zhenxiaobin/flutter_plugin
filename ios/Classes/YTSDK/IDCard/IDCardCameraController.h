//
//  IDCardCameraController.h
//  IDCardDemo
//
//  Created by ocrgroup on 2017/9/28.
//  Copyright © 2017年 ocrgroup. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol IDCardCameraDelegate <NSObject>

@required


/**
 Camera识别成功回调
 
 @param cameraController 相机控制器对象
 @param resultDic 识别结果
 @param frontOrBack 是正面还是背面(1-Front 2-Back 0-未知(拍照识别识别失败返回该值))
 @param errorCode 错误码
 @param cardImage 图像
 */
- (void)cameraController:(UIViewController *)cameraController audioRecognizeFinishWithResult:(NSDictionary *)resultDic isFrontOrBack:(int)frontOrBack errorCode:(int)errorCode andImage:(UIImage *)cardImage andImageHead:(UIImage *)imageHead;


@optional
/**
 Camera点击返回回调
 
 @param cameraController 相机控制器(内部已pop和dismiss,外部无需做,此回调为混合开发项目提供)
 */
- (void)backButtonClickWithIDCardCameraController:(UIViewController *)cameraController;


@end

@interface IDCardCameraController : UIViewController

/** 识别成功回调 */
@property (weak, nonatomic) id <IDCardCameraDelegate> delegate;

/** (识别成功时)是否振动 */
@property (nonatomic, assign) BOOL whetherVibrate;

@end
