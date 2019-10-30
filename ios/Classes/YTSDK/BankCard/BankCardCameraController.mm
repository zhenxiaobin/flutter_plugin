//
//  BankCardCameraController.m
//  SBankCardDemo
//
//  Created by ocrgroup on 2017/9/27.
//  Copyright © 2017年 ocrgroup. All rights reserved.
//

#import "BankCardCameraController.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>
#import "SquareView.h"
#import "SBankCard.h"
#import "SBankCardInfo.h"

//顶部安全区
#define SafeAreaTopHeight (SCREENH == 812.0 ? 44 : 10)

#define SCREENH [UIScreen mainScreen].bounds.size.height
#define SCREENW [UIScreen mainScreen].bounds.size.width
#define SCREENRECT [UIScreen mainScreen].bounds

@interface BankCardCameraController ()<UIAlertViewDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>

/** 横/竖屏 */
@property (nonatomic, assign) BankCardAudioDirection direction;

@property (nonatomic, strong) UITapGestureRecognizer * singleTap;

@property (nonatomic, strong) UIButton * flashBtn;
@property (nonatomic, strong) UIButton * backBtn;
@property (nonatomic, strong) UIButton * changeBtn;
//"将框置于VIN码前"
@property (nonatomic, strong) UILabel * centerLabel;
//"点击继续拍照"拍完照之后的提示Label
@property (nonatomic, strong) UILabel * topLabel;
//检测结果
@property (nonatomic, strong) UILabel * resultLabel;
//详细信息
@property (nonatomic, strong) UILabel * detailInfoLabel;
//检测的结果图片
@property (nonatomic, strong) UIImageView * resultImageView;
//示例卡号
@property (nonatomic, strong) UILabel * exampleLabel;
//提示文字
@property (nonatomic, strong) UILabel * promptLabel;

//方框view
@property (nonatomic, strong) SquareView * topView;
//检测视图层
@property (nonatomic, strong) CAShapeLayer * detectLayer;

//相机相关
@property (nonatomic, strong) AVCaptureSession * captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput * captureInput;
@property (nonatomic, strong) AVCaptureStillImageOutput * captureOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput * captureDataOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer * capturePreviewLayer;
@property (nonatomic, strong) AVCaptureDevice * captureDevice;


@end

@implementation BankCardCameraController {
    
    NSString * _authorizationCode;  //公司名 / 授权码
    
    SBankCard * _sBankCard; //识别核心
    SBankCardInfo * _sBankCardInfo; //银行卡号信息
    BOOL _isCameraAuthor; //是否有打开摄像头权限
    BOOL _isRecognize; //是否识别
    BOOL _flash; //控制闪光灯
    BOOL _isTransform;
    NSTimer * _timer;
    BOOL _isFocusing;//是否正在对焦
    BOOL _isFocusPixels;//是否相位对焦
    GLfloat _FocusPixelsPosition;//相位对焦下镜头位置
    GLfloat _curPosition;//当前镜头位置
}

- (instancetype)init {
    if (self = [super init]) {
        _authorizationCode = @"947C5EC227912874BCB9";
        _direction = kAudioDirectionVertical;
    }
    return self;
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.navigationController.navigationBarHidden = YES;
    
    
    //初始化识别核心
    [self performSelectorInBackground:@selector(initRecogKernal) withObject:nil];
    //初始化相机和视图层
    [self initCamera];
    //UI
    [self prepareUI];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _isRecognize = YES;
    AVCaptureDevice * camDevice =[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //注册通知
    [camDevice addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:nil];
    if (_isFocusPixels) {
        [camDevice addObserver:self forKeyPath:@"lensPosition" options:NSKeyValueObservingOptionNew context:nil];
    }
    [self.captureSession startRunning];
    
    [self initRecognizeCore];
    
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _isRecognize = NO;
    //关闭定时器
    [_timer invalidate];
    _timer = nil;
    //释放核心
    [_sBankCard freeSBankCard];
    [_sBankCardInfo freeSBankCardInfo];
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    AVCaptureDevice*camDevice =[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [camDevice removeObserver:self forKeyPath:@"adjustingFocus"];
    if (_isFocusPixels) {
        [camDevice removeObserver:self forKeyPath:@"lensPosition"];
    }
    [self.captureSession stopRunning];
    
}

#pragma mark - 屏幕适配
- (CGFloat)getRatio {
    return SCREENH / 568.0;
}

#pragma mark - 初始化

//隐藏状态栏
- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}
- (BOOL)prefersStatusBarHidden {
    return YES;
}

//初始化识别核心
- (void)initRecogKernal {
    _sBankCard = [[SBankCard alloc] init];
    _sBankCardInfo = [[SBankCardInfo alloc] init];
}


- (void)initRecognizeCore {
    //初始化识别核心
    int nRet = [_sBankCard initSBankCard:_authorizationCode nsReserve:@""];
    if ([self.delegate respondsToSelector:@selector(initBankCardWithResult:)]) {
        [self.delegate initBankCardWithResult:nRet];
    }
    int nSuccess = [_sBankCardInfo initSBankCardInfo]; //return 1
    //    NSLog(@"nSuccess:%d",nSuccess);
    if (nRet != 0) {
        if (_isCameraAuthor == NO) {
            [self.captureSession stopRunning];
            NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
            NSArray * appleLanguages = [defaults objectForKey:@"AppleLanguages"];
            NSString * systemLanguage = [appleLanguages objectAtIndex:0];
            if (![systemLanguage isEqualToString:@"zh-Hans"]) {
                NSString *initStr = [NSString stringWithFormat:@"Init Error!Error code:%d",nRet];
                UIAlertView *alertV = [[UIAlertView alloc] initWithTitle:@"Tips" message:initStr delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [alertV show];
            }else{
                NSString *initStr = [NSString stringWithFormat:@"初始化失败!错误代码:%d",nRet];
                UIAlertView *alertV = [[UIAlertView alloc] initWithTitle:@"提示" message:initStr delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [alertV show];
            }
        }
    }
}

//初始化相机
- (void)initCamera {
    //判断摄像头是否授权
    _isCameraAuthor = NO;
    AVAuthorizationStatus authorStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if(authorStatus == AVAuthorizationStatusRestricted || authorStatus == AVAuthorizationStatusDenied){
        NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
        NSArray * allLanguages = [userDefaults objectForKey:@"AppleLanguages"];
        NSString * preferredLang = [allLanguages objectAtIndex:0];
        if (![preferredLang isEqualToString:@"zh-Hans"]) {
            UIAlertView * alt = [[UIAlertView alloc] initWithTitle:@"Please allow to access your device’s camera in “Settings”-“Privacy”-“Camera”" message:@"" delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alt show];
        }else{
            UIAlertView * alt = [[UIAlertView alloc] initWithTitle:@"未获得授权使用摄像头" message:@"请在 '设置-隐私-相机' 中打开" delegate:self cancelButtonTitle:nil otherButtonTitles:@"知道了", nil];
            [alt show];
        }
        _isCameraAuthor = YES;
        return;
    }
    
    
    //创建、配置输入
    NSArray * devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionBack){
            self.captureDevice = device;
            self.captureInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
        }
    }
    
    //输入设备
    [self.captureSession addInput:self.captureInput];
    //输出设备
    [self.captureSession addOutput:self.captureDataOutput];
    //输出设备
    [self.captureSession addOutput:self.captureOutput];
    //添加预览层
    [self.view.layer addSublayer:self.capturePreviewLayer];
    //开启相机
    [self.captureSession startRunning];
    
    
    //判断是否相位对焦
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
        AVCaptureDeviceFormat *deviceFormat = self.captureDevice.activeFormat;
        if (deviceFormat.autoFocusSystem == AVCaptureAutoFocusSystemPhaseDetection) {
            _isFocusPixels = YES;
        }
    }
    
    //计算设置银行卡的检测区域
    [self setBankCardDetectArea];
    
    if (self.direction == kAudioDirectionHorizontal) {
        [_sBankCard setRecognizeType:0];
    }else{
        [_sBankCard setRecognizeType:1];
    }
    
}

- (void)setBankCardDetectArea {
    if (self.direction == kAudioDirectionHorizontal) {
        //因为传参需要横屏的数值,所以计算横屏的x,y,height,width
        CGFloat x,y,h,w;
        x = self.topView.squareFrame.origin.y;
        y = self.topView.squareFrame.origin.x;
        h = self.topView.squareFrame.size.width;
        w = self.topView.squareFrame.size.height;
        
        NSLog(@"x%f,y%f,w%f,h%f",x,y,w,h);
        
        //计算参数
        int left,top,right,bottom;
        left = x / SCREENH * 1280;
        top = y / SCREENW * 720 - 60; //
        right = (x + w) / SCREENH * 1280;
        bottom = (y + h) / SCREENW * 720 + 60;  //
        NSLog(@"算left%d top%d right%d bottom%d",left,top,right,bottom);
        //设置检测范围
        //        [_sBankCard setRegionWithLeft:225 Top:100 Right:1025 Bottom:618];
        [_sBankCard setRegionWithLeft:left Top:top Right:right Bottom:bottom];
    }else{
        //竖屏计算是按照squareView为竖屏的方式计算
        CGFloat x,y,h,w;
        x = self.topView.squareFrame.origin.x;
        y = self.topView.squareFrame.origin.y;
        h = self.topView.squareFrame.size.height;
        w = self.topView.squareFrame.size.width;
        
        //计算参数
        int left,top,right,bottom;
        left = x / SCREENW * 720;
        top = y / SCREENH * 1280;
        right = (x + w) / SCREENW * 720;
        bottom = (y + h) / SCREENH * 1280;
        //        [_sBankCard setRegionWithLeft:44 Top:425 Right:676 Bottom:854];
        NSLog(@"算left%d top%d right%d bottom%d",left,top,right,bottom);
        //设置检测范围
        [_sBankCard setRegionWithLeft:left Top:top Right:right Bottom:bottom];
    }
}

//计算检测视图层的空洞layer
- (CAShapeLayer *)getLayerWithHole {
    CGFloat offset = 1.0f;
    if ([UIScreen mainScreen].scale >= 2) {
        offset = 0.5;
    }
    
    CGRect topViewRect = self.topView.squareFrame;
    
    CGRect centerRect = CGRectInset(topViewRect, -offset, -offset) ;
    UIBezierPath *bezierPath = [UIBezierPath bezierPath];
    [bezierPath moveToPoint:CGPointMake(CGRectGetMinX(SCREENRECT), CGRectGetMinY(SCREENRECT))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMinX(SCREENRECT), CGRectGetMaxY(SCREENRECT))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMaxX(SCREENRECT), CGRectGetMaxY(SCREENRECT))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMaxX(SCREENRECT), CGRectGetMinY(SCREENRECT))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMinX(SCREENRECT), CGRectGetMinY(SCREENRECT))];
    [bezierPath moveToPoint:CGPointMake(CGRectGetMinX(centerRect), CGRectGetMinY(centerRect))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMinX(centerRect), CGRectGetMaxY(centerRect))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMaxX(centerRect), CGRectGetMaxY(centerRect))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMaxX(centerRect), CGRectGetMinY(centerRect))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMinX(centerRect), CGRectGetMinY(centerRect))];
    CAShapeLayer *layerWithHole = [CAShapeLayer layer];
    [layerWithHole setPath:bezierPath.CGPath];
    [layerWithHole setFillRule:kCAFillRuleEvenOdd];
    [layerWithHole setFillColor:[UIColor colorWithWhite:0 alpha:0.35].CGColor];
    
    return layerWithHole;
    
}

- (void)prepareUI {
    
    [self.view.layer addSublayer:self.detectLayer];
    self.view.layer.masksToBounds = YES;
    
    [self.view addSubview:self.topView];
    
    [self.view addGestureRecognizer:self.singleTap];
    
    
    [self.view addSubview:self.flashBtn];
    
    [self.view addSubview:self.backBtn];
    
    [self.view addSubview:self.changeBtn];
    
    [self.view addSubview:self.centerLabel];
    
    [self.view addSubview:self.detailInfoLabel];
    
    [self.view addSubview:self.resultLabel];
    
    [self.view addSubview:self.topLabel];
    
    [self.view addSubview:self.exampleLabel];
    
    
    [self.view addSubview:self.resultImageView];
    
    [self.view addSubview:self.promptLabel];
    
    if (self.direction == kAudioDirectionHorizontal) {
        [self frameSetupHorizontal];
    }else{
        [self frameSetupVertical];
    }
    
}

/** 横屏布局 */
- (void)frameSetupHorizontal {
    
    CGFloat ratio = [self getRatio];
    
    CGFloat width;
    width = 60 * ratio;
    
    self.promptLabel.frame = CGRectMake(0, SCREENH - 80, SCREENW, 25);
    
    
    self.flashBtn.frame = CGRectMake(SCREENW - width - 10, SafeAreaTopHeight, width, width);
    
    self.changeBtn.frame = CGRectMake(0, 0, width, width);
    self.changeBtn.center = CGPointMake(SCREENW * 0.5, width * 0.5 + SafeAreaTopHeight);
    
    self.backBtn.frame = CGRectMake(10, SafeAreaTopHeight, width, width);
    
    CGPoint center;
    center.x = CGRectGetMidX(self.topView.squareFrame);
    center.y = CGRectGetMidY(self.topView.squareFrame);
    
    
    self.centerLabel.frame = CGRectMake(0, 0, 147, 25);
    self.centerLabel.numberOfLines = 0;
    self.centerLabel.center = center;
    self.centerLabel.layer.cornerRadius = self.centerLabel.frame.size.height / 2;
    self.centerLabel.layer.masksToBounds = YES;
    
    self.exampleLabel.frame = CGRectMake(0, 0, self.topView.squareFrame.size.height, 32);
    CGPoint examLabelCenter = center;
    examLabelCenter.x = center.x - 27;
    self.exampleLabel.center = examLabelCenter;
    
    
    //"点击继续拍照"拍完照之后的提示Label
    self.topLabel.frame = CGRectMake(0, 0, 147, 25);
    CGPoint topLabelCenter = center;
    topLabelCenter.x = SCREENW - self.topLabel.frame.size.height / 2 - 5;
    self.topLabel.center = topLabelCenter;
    self.topLabel.layer.cornerRadius = self.topLabel.frame.size.height / 2;
    self.topLabel.layer.masksToBounds = YES;
    
    
    
    self.resultImageView.frame = CGRectMake(0, 0, self.topView.squareFrame.size.height, 70);
    CGPoint resultImageCenter = center;
    resultImageCenter.x -= (self.topView.squareFrame.size.width - self.resultImageView.frame.size.height) * 0.5;
    self.resultImageView.center = resultImageCenter;
    
    
    //结果
    self.resultLabel.frame = CGRectMake(0, 0, 375 * ratio, 60 * ratio);
    CGPoint resultLabelCenter = center;
    resultLabelCenter.x = center.x - (self.topView.squareFrame.size.width / 2 - self.resultImageView.frame.size.height) + self.resultLabel.frame.size.height / 2;
    self.resultLabel.center = resultLabelCenter;
    
    
    
    //详细信息
    self.detailInfoLabel.frame = CGRectMake(0, 0, 300, 80);
    CGPoint detailInfoCenter = center;
    detailInfoCenter.x = center.x - self.topView.squareFrame.size.width / 2 + self.resultLabel.frame.size.height + self.resultImageView.frame.size.height + self.detailInfoLabel.frame.size.height / 2;
    self.detailInfoLabel.center = detailInfoCenter;
    
    
    //横屏需要旋转
    self.backBtn.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.flashBtn.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.changeBtn.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.centerLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.topLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.resultLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.detailInfoLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.resultImageView.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.exampleLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
    
}

/** 竖屏布局 */
- (void)frameSetupVertical {
    
    CGFloat ratio = [self getRatio];
    
    CGFloat width;
    width = 60 * ratio;
    
    self.promptLabel.frame = CGRectMake(0, SCREENH - 80, SCREENW, 25);
    
    
    self.flashBtn.frame = CGRectMake(SCREENW - width - 10, SafeAreaTopHeight, width, width);
    
    self.changeBtn.frame = CGRectMake(0, 0, width, width);
    self.changeBtn.center = CGPointMake(SCREENW * 0.5, width * 0.5 + SafeAreaTopHeight);
    
    self.backBtn.frame = CGRectMake(10, SafeAreaTopHeight, width, width);
    
    CGPoint center;
    center.x = CGRectGetMidX(self.topView.squareFrame);
    center.y = CGRectGetMidY(self.topView.squareFrame);
    
    
    self.centerLabel.frame = CGRectMake(0, 0, 147, 25);
    self.centerLabel.numberOfLines = 0;
    self.centerLabel.center = center;
    self.centerLabel.layer.cornerRadius = self.centerLabel.frame.size.height / 2;
    self.centerLabel.layer.masksToBounds = YES;
    
    self.exampleLabel.frame = CGRectMake(0, 0, self.topView.squareFrame.size.width, 32);
    CGPoint examLabelCenter = center;
    examLabelCenter.y = center.y + 27;
    self.exampleLabel.center = examLabelCenter;
    
    
    //"点击继续拍照"拍完照之后的提示Label
    self.topLabel.frame = CGRectMake(0, 0, 147, 25);
    CGPoint topLabelCenter = center;
    topLabelCenter.y = self.topLabel.frame.size.height / 2 + 5 + self.changeBtn.frame.size.height + SafeAreaTopHeight;
    self.topLabel.center = topLabelCenter;
    self.topLabel.layer.cornerRadius = self.topLabel.frame.size.height / 2;
    self.topLabel.layer.masksToBounds = YES;
    
    
    
    self.resultImageView.frame = CGRectMake(0, 0, self.topView.squareFrame.size.width, 70);
    CGPoint resultImageCenter = center;
    resultImageCenter.y += (self.topView.squareFrame.size.height - self.resultImageView.frame.size.height) * 0.5;
    self.resultImageView.center = resultImageCenter;
    
    
    //结果
    self.resultLabel.frame = CGRectMake(0, 0, 375 * ratio, 60 * ratio);
    CGPoint resultLabelCenter = center;
    resultLabelCenter.y += self.topView.squareFrame.size.height / 2 - self.resultImageView.frame.size.height - self.resultLabel.frame.size.height / 2;
    self.resultLabel.center = resultLabelCenter;
    
    
    
    //详细信息
    self.detailInfoLabel.frame = CGRectMake(0, 0, 300, 77);
    CGPoint detailInfoCenter = center;
    detailInfoCenter.y += self.topView.squareFrame.size.height / 2 - self.resultLabel.frame.size.height - self.detailInfoLabel.frame.size.height / 2 - self.resultImageView.frame.size.height;
    self.detailInfoLabel.center = detailInfoCenter;
    
    
}

- (void)clearSubViewsUp {
    
    [self.detectLayer removeFromSuperlayer];
    self.detectLayer = nil;
    
    [self.view removeGestureRecognizer:self.singleTap];
    
    [self.exampleLabel removeFromSuperview];
    self.exampleLabel = nil;
    
    [self.topView removeFromSuperview];
    self.topView = nil;
    [self.flashBtn removeFromSuperview];
    self.flashBtn = nil;
    [self.backBtn removeFromSuperview];
    self.backBtn = nil;
    [self.changeBtn removeFromSuperview];
    self.changeBtn = nil;
    [self.centerLabel removeFromSuperview];
    self.centerLabel = nil;
    [self.resultLabel removeFromSuperview];
    self.resultLabel = nil;
    [self.topLabel removeFromSuperview];
    self.topLabel = nil;
    [self.detailInfoLabel removeFromSuperview];
    self.detailInfoLabel = nil;
    [self.resultImageView removeFromSuperview];
    self.resultImageView = nil;
}


//监听对焦
-(void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    if([keyPath isEqualToString:@"adjustingFocus"]){
        _isFocusing = [[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1]];
    }
    if([keyPath isEqualToString:@"lensPosition"]){
        _FocusPixelsPosition = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
    }
}




//从缓冲区获取图像数据进行识别
#pragma mark -
#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    if(!_isFocusing){
        if (_isRecognize) {
            if(_curPosition == _FocusPixelsPosition){
                //开始识别
                int bSuccess = [_sBankCard recognizeSBankCard:baseAddress Width:(int)width Height:(int)height];
                //                NSLog(@"bSuccess:%d",bSuccess);
                //识别成功
                if(bSuccess == 0){
                    //震动
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                    //显示区域图像
                    [self performSelectorOnMainThread:@selector(showResultAndImage:) withObject:_sBankCard.resultImg waitUntilDone:NO];
                    _isRecognize = NO;
                }
            }else{
                _curPosition = _FocusPixelsPosition;
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
}

//显示结果跟图像
-(void)showResultAndImage:(UIImage *)image {
    [self.resultImageView setImage:image];
    //全图保存至相册
//        UIImageWriteToSavedPhotosAlbum(_sBankCard.bankCardImg, self, nil, NULL);
    [_sBankCardInfo getSBankCardInfo:_sBankCard.nsNo];
//    NSString *nsResult = [NSString stringWithFormat:@"开户行名称:%@\n银行卡名称:%@\n银行卡类型:%@\n银行代码:%@",_sBankCardInfo.nsBankName,_sBankCardInfo.nsCardName,_sBankCardInfo.nsCardType,_sBankCardInfo.nsBankCode];
//    self.resultLabel.text = _sBankCard.nsNo;
//    self.detailInfoLabel.text = nsResult;
//    self.centerLabel.hidden = YES;
//    self.exampleLabel.hidden = YES;
//    self.topLabel.hidden = NO;
//    if (self.resultImg) {
//        self.resultImg = nil;
//    }
    NSDictionary *dict = @{@"bankNo":_sBankCard.nsNo,
                           @"bankCardImg":_sBankCard.bankCardImg,
                           @"bankName":_sBankCardInfo.nsBankName,
                           @"cardName":_sBankCardInfo.nsCardName,
                           @"cardType":_sBankCardInfo.nsCardType,
                           @"bankCode":_sBankCardInfo.nsBankCode};
    if ([self.delegate respondsToSelector:@selector(getBankCardInfo:)]) {
        [self.delegate getBankCardInfo:dict];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 点击事件

//横屏 / 竖屏 切换
- (void)changeBtnClick {
    
    if (self.direction == kAudioDirectionHorizontal) {
        self.direction = kAudioDirectionVertical;
        
    }else{
        self.direction = kAudioDirectionHorizontal;
        
    }
    _isRecognize = YES;
    self.resultLabel.text = @"";
    self.topLabel.hidden = YES;
    self.centerLabel.hidden = NO;
    self.resultImageView.image = nil;
    if (!self.captureSession.isRunning) {
        [self.captureSession startRunning];
    }
}

//闪光灯按钮点击事件
- (void)flashBtnClick{
    
    if (!self.captureDevice.hasTorch) {
        //NSLog(@"no torch");
    }else{
        [self.captureDevice lockForConfiguration:nil];
        if(!_flash){
            [self.captureDevice setTorchMode: AVCaptureTorchModeOn];
            [self.flashBtn setImage:[self getImageWithName:@"flash_off"] forState:UIControlStateNormal];
            _flash = YES;
        }
        else{
            [self.captureDevice setTorchMode: AVCaptureTorchModeOff];
            [self.flashBtn setImage:[self getImageWithName:@"flash_on"] forState:UIControlStateNormal];
            _flash = NO;
        }
        [self.captureDevice unlockForConfiguration];
    }
    
}

//返回按钮点击事件
- (void)backBtnClick{
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark 手势
//单击手势
- (void)handleSingleFingerEvent:(UITapGestureRecognizer *)sender {
    if (sender.numberOfTapsRequired == 1) {
        //单指单击
        _isRecognize = YES;
        self.resultLabel.text = @"";
        self.topLabel.hidden = YES;
        self.detailInfoLabel.text = @"";
        self.centerLabel.hidden = NO;
        self.exampleLabel.hidden = NO;
        [self.resultImageView setImage:nil];
    }
}


- (AVCaptureDevice *)captureDevicePosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}


#pragma mark - 懒加载


#pragma mark - Setter
- (void)setDirection:(BankCardAudioDirection)direction {
    _direction = direction;
    
    [self clearSubViewsUp];
    
    [self prepareUI];
    
    NSLog(@"direction:%lu",(unsigned long)direction);
    if (direction == kAudioDirectionHorizontal) {
        [_sBankCard setRecognizeType:0];
        
    }else{
        [_sBankCard setRecognizeType:1];
    }
    
    [self setBankCardDetectArea];
    
}

#pragma mark - Getter

#pragma mark 相机相关

- (AVCaptureSession *)captureSession {
    if (!_captureSession) {
        //创建会话层,视频浏览分辨率为1280*720
        _captureSession = [[AVCaptureSession alloc] init];
        [_captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
    }
    return _captureSession;
}

- (AVCaptureDeviceInput *)captureInput {
    if (!_captureInput) {
        _captureInput = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice error:nil];
    }
    return _captureInput;
    
}

- (AVCaptureStillImageOutput *)captureOutput {
    if (!_captureOutput) {
        //创建、配置输出
        _captureOutput = [[AVCaptureStillImageOutput alloc] init];
        NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
        [_captureOutput setOutputSettings:outputSettings];
    }
    return _captureOutput;
}

- (AVCaptureVideoDataOutput *)captureDataOutput {
    if (!_captureDataOutput) {
        _captureDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        _captureDataOutput.alwaysDiscardsLateVideoFrames = YES;
        dispatch_queue_t queue;
        queue = dispatch_queue_create("cameraQueue", NULL);
        [_captureDataOutput setSampleBufferDelegate:self queue:queue];
        NSString* formatKey = (NSString*)kCVPixelBufferPixelFormatTypeKey;
        NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
        NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:formatKey];
        [_captureDataOutput setVideoSettings:videoSettings];
    }
    return _captureDataOutput;
}

- (AVCaptureVideoPreviewLayer *)capturePreviewLayer {
    if (!_capturePreviewLayer) {
        _capturePreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession: self.captureSession];
        _capturePreviewLayer.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
        _capturePreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    return _capturePreviewLayer;
}

- (AVCaptureDevice *)captureDevice {
    if (!_captureDevice) {
        NSArray *deviceArr = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in deviceArr)
        {
            if (device.position == AVCaptureDevicePositionBack){
                _captureDevice = device;
                _captureInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
            }
        }
    }
    return _captureDevice;
}

#pragma mark UI相关

- (UITapGestureRecognizer *)singleTap {
    if (!_singleTap) {
        _singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleFingerEvent:)];
        
    }
    return _singleTap;
}

- (UIButton *)flashBtn {
    if (!_flashBtn) {
        _flashBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _flashBtn.tag = 1000;
        _flashBtn.hidden = NO;
        [_flashBtn setImage:[self getImageWithName:@"flash_on"] forState:UIControlStateNormal];
        [_flashBtn addTarget:self action:@selector(flashBtnClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _flashBtn;
}

- (UIButton *)backBtn {
    if (!_backBtn) {
        _backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _backBtn.tag = 1000;
        _backBtn.hidden = NO;
        [_backBtn setImage:[self getImageWithName:@"back_btn"] forState:UIControlStateNormal];
        [_backBtn addTarget:self action:@selector(backBtnClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _backBtn;
}

- (UIButton *)changeBtn {
    if (!_changeBtn) {
        _changeBtn = [[UIButton alloc] init];
        _changeBtn.hidden = NO;
        [_changeBtn setImage:[self getImageWithName:@"change_btn"] forState:UIControlStateNormal];
        [_changeBtn addTarget:self action:@selector(changeBtnClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _changeBtn;
}


- (SquareView *)topView {
    if (!_topView) {
        _topView = [[SquareView alloc] initWithDirection:self.direction];
        _topView.backgroundColor = [UIColor clearColor];
    }
    return _topView;
}

- (UILabel *)centerLabel {
    if (!_centerLabel) {
        _centerLabel = [[UILabel alloc] init];
        _centerLabel.text = @"请将银行卡置于框内";
        _centerLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
        _centerLabel.font = [UIFont fontWithName:@"Helvetica" size:15];
        _centerLabel.textColor = [UIColor whiteColor];
        _centerLabel.textAlignment = NSTextAlignmentCenter;
        _centerLabel.hidden = NO;
    }
    return _centerLabel;
}

- (UILabel *)promptLabel {
    if (!_promptLabel) {
        _promptLabel = [[UILabel alloc] init];
        _promptLabel.text = @"请尽量使用真实银行卡，在光线明亮的地方进行扫描";
        _promptLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
        _promptLabel.font = [UIFont fontWithName:@"Helvetica" size:15];
        _promptLabel.textColor = [UIColor whiteColor];
        _promptLabel.backgroundColor = [UIColor clearColor];
        _promptLabel.textAlignment = NSTextAlignmentCenter;
        _promptLabel.hidden = NO;
    }
    return _promptLabel;
}



- (UILabel *)topLabel {
    if (!_topLabel) {
        _topLabel = [[UILabel alloc] init];
        _topLabel.text = @"点击屏幕继续识别";
        _topLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
        _topLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
        _topLabel.font = [UIFont fontWithName:@"Helvetica" size:15];
        _topLabel.textColor = [UIColor whiteColor];
        _topLabel.textAlignment = NSTextAlignmentCenter;
        
        _topLabel.hidden = YES;
    }
    return _topLabel;
}


- (UILabel *)resultLabel {
    if (!_resultLabel) {
        CGFloat ratio = SCREENH / 568.0;
        int nSize = 22;
        if(ratio>1.0) nSize = 32;
        _resultLabel = [[UILabel alloc] init];
        _resultLabel.text = @"";
        _resultLabel.font = [UIFont fontWithName:@"Helvetica" size:nSize];
        _resultLabel.textColor = [UIColor greenColor];
        _resultLabel.textAlignment = NSTextAlignmentCenter;
        
    }
    return _resultLabel;
}

- (UILabel *)detailInfoLabel {
    if (!_detailInfoLabel) {
        _detailInfoLabel = [[UILabel alloc] init];
        _detailInfoLabel.text = @"";
        _detailInfoLabel.numberOfLines = 0;
        _detailInfoLabel.font = [UIFont fontWithName:@"Helvetica" size:15];
        _detailInfoLabel.textColor = [UIColor greenColor];
        _detailInfoLabel.textAlignment = NSTextAlignmentLeft;
        
    }
    return _detailInfoLabel;
}

- (UILabel *)exampleLabel {
    if (!_exampleLabel) {
        _exampleLabel = [[UILabel alloc] init];
        _exampleLabel.text = @"1234 5678 9012 345";
        if (SCREENW < 400 || (self.direction == kAudioDirectionVertical && SCREENW <= 420)) {
            _exampleLabel.font = [UIFont fontWithName:@"Courier-Bold" size:31];
        }else{
            _exampleLabel.font = [UIFont fontWithName:@"Courier-Bold" size:40];
        }
        
        _exampleLabel.textColor = [UIColor whiteColor];
        _exampleLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _exampleLabel;
}

- (UIImageView *)resultImageView {
    if (!_resultImageView) {
        _resultImageView = [[UIImageView alloc] init];
        _resultImageView.image = nil;
        
    }
    return _resultImageView;
}

- (CAShapeLayer *)detectLayer {
    if (!_detectLayer) {
        //设置检测视图层
        _detectLayer = [self getLayerWithHole];
        
    }
    return _detectLayer;
}

- (UIImage *)getImageWithName:(NSString *)name
{
    NSURL *bundleURL = [[NSBundle mainBundle] URLForResource:@"Frameworks" withExtension:nil];
    bundleURL = [bundleURL URLByAppendingPathComponent:@"flutter_plugin_utils"];
    bundleURL = [bundleURL URLByAppendingPathExtension:@"framework"];
    NSBundle *bunle = [NSBundle bundleWithURL:bundleURL];
    UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"ImageResource.bundle/%@", name]
                                inBundle:bunle
           compatibleWithTraitCollection:nil];
    return image;
}

- (void)dealloc {
    NSLog(@"dealloc");
}

@end
