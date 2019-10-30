//
//  IDCardCameraController.m
//  IDCardDemo
//
//  Created by ocrgroup on 2017/9/28.
//  Copyright © 2017年 ocrgroup. All rights reserved.
//

#import "IDCardCameraController.h"
#import "IDCardSquareView.h"
#import "SIDCard.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreMotion/CoreMotion.h>
#import "Masonry.h"

//顶部安全区
#define SafeAreaTopHeight (SCREENH == 812.0 ? 44 : 10)
//底部
#define SafeAreaBottomHeight (SCREENH == 812.0 ? 34 : 0)

#define SCREENH [UIScreen mainScreen].bounds.size.height
#define SCREENW [UIScreen mainScreen].bounds.size.width
#define SCREENRECT [UIScreen mainScreen].bounds

@interface IDCardCameraController () <UIAlertViewDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) UIButton * flashBtn;
@property (nonatomic, strong) UIButton * changeTypeBtn; // 改变识别方式
@property (nonatomic, strong) UIButton * cameraBtn;
@property (nonatomic, strong) UIButton * backBtn;
@property (nonatomic, strong) UIImageView * scanLine;
@property (nonatomic, strong) IDCardSquareView * topView;
@property (nonatomic, strong) CMMotionManager * motionManager;

//"将框置于VIN码前"
@property (nonatomic, strong) UILabel * centerLabel;
@property (nonatomic, assign) CGPoint linePoint;//扫描线初始位置
@property (nonatomic, strong) SIDCard * sIDCard;
//提示文字
@property (nonatomic, strong) UILabel * promptLabel;

//相机相关
@property (nonatomic, strong) AVCaptureSession * captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput * captureInput;
@property (nonatomic, strong) AVCaptureStillImageOutput * captureOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput * captureDataOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer * capturePreviewLayer;
@property (nonatomic, strong) AVCaptureDevice * captureDevice;

@end

@implementation IDCardCameraController
{
    NSString * _authorizationCode;  //授权码
    BOOL _isCameraAuthor; //是否有打开摄像头权限
    BOOL _isRecognize; //是否识别
    BOOL _isChangeType;//识别方式切换
    BOOL _isPhotoRecog;//是否是拍照识别
    BOOL _flash; //控制闪光灯
    BOOL _isTransform;
    BOOL _isFocusing;//是否正在对焦
    BOOL _isFocusPixels;//是否相位对焦
    GLfloat _FocusPixelsPosition;//相位对焦下镜头位置
    GLfloat _curPosition;//当前镜头位置
}

- (instancetype)init
{
    if (self = [super init]) {
        _authorizationCode = @"947C5EC227912874BCB9";
    }
    return self;
}

#pragma mark - Life Circle
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
//    self.navigationController.navigationBarHidden = YES;
    
    //初始化识别核心
    self.sIDCard = [[SIDCard alloc] init];
    //初始化相机和视图层
    [self initCameraAndLayer];
    _isChangeType = YES;
    [self prepareUI];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    _isRecognize = YES;
    AVCaptureDevice * camDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //注册通知
    [camDevice addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:nil];
    if (_isFocusPixels) {
        [camDevice addObserver:self forKeyPath:@"lensPosition" options:NSKeyValueObservingOptionNew context:nil];
    }
    [self.captureSession startRunning];
    [self performSelector:@selector(moveScanline)];
    //重力感应
    [self startMotionManager];
    //监听切换到前台事件
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    //初始化识别核心
    int nRet = [_sIDCard initSIDCard:_authorizationCode nsReserve:@""];
    
    if (nRet != 0) {
        if (_isCameraAuthor == NO) {
            [self.captureSession stopRunning];
            NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
            NSArray * appleLanguages = [defaults objectForKey:@"AppleLanguages"];
            NSString * systemLanguage = [appleLanguages objectAtIndex:0];
            if (![systemLanguage isEqualToString:@"zh-Hans"]) {
                NSString *initStr = [NSString stringWithFormat:@"Init Error!Error code:%d",nRet];
                UIAlertView *alertV = [[UIAlertView alloc]initWithTitle:@"Tips" message:initStr delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [alertV show];
            }else{
                NSString *initStr = [NSString stringWithFormat:@"初始化失败!错误代码:%d",nRet];
                UIAlertView *alertV = [[UIAlertView alloc]initWithTitle:@"提示" message:initStr delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [alertV show];
            }
        }
    }
    //设置证件识别类型（0-自动、1-正面、2－背面）
    if(nRet == 0){
        [_sIDCard setRecognizeType:0];
    }
}

- (void)didBecomeActive
{
    [self performSelector:@selector(moveScanline)];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _isRecognize = NO;
    //移除监听
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    //停止重力加速检测
    [self.motionManager stopDeviceMotionUpdates];
    //释放核心
    [_sIDCard freeSIDCard];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    AVCaptureDevice * camDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [camDevice removeObserver:self forKeyPath:@"adjustingFocus"];
    if (_isFocusPixels) {
        [camDevice removeObserver:self forKeyPath:@"lensPosition"];
    }
    [self.captureSession stopRunning];
}

#pragma mark - 屏幕适配
- (CGFloat)getRatio
{
    return SCREENH / 568.0;
}

#pragma mark - 初始化
//初始化相机和检测视图层
- (void)initCameraAndLayer
{
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
    
    //输入设备
    [self.captureSession addInput:self.captureInput];
    //输出设备
    [self.captureSession addOutput:self.captureDataOutput];
    //输出设备
    [self.captureSession addOutput:self.captureOutput];
    //添加预览层
    [self.view.layer addSublayer:self.capturePreviewLayer];
    
    [self.captureSession startRunning];
    
    //设置检测视图层
    CAShapeLayer * layerWithHole = [CAShapeLayer layer];
    
    CGRect screenRect = self.view.bounds;
    CGFloat offset = 1.0f;
    if ([[UIScreen mainScreen] scale] >= 2) {
        offset = 0.5;
    }
    
    CGRect centerFrame = self.topView.squareFrame;
    CGRect centerRect = CGRectInset(centerFrame, -offset, -offset) ;
    
    UIBezierPath *bezierPath = [UIBezierPath bezierPath];
    [bezierPath moveToPoint:CGPointMake(CGRectGetMinX(screenRect), CGRectGetMinY(screenRect))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMinX(screenRect), CGRectGetMaxY(screenRect))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMaxX(screenRect), CGRectGetMaxY(screenRect))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMaxX(screenRect), CGRectGetMinY(screenRect))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMinX(screenRect), CGRectGetMinY(screenRect))];
    [bezierPath moveToPoint:CGPointMake(CGRectGetMinX(centerRect), CGRectGetMinY(centerRect))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMinX(centerRect), CGRectGetMaxY(centerRect))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMaxX(centerRect), CGRectGetMaxY(centerRect))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMaxX(centerRect), CGRectGetMinY(centerRect))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetMinX(centerRect), CGRectGetMinY(centerRect))];
    [layerWithHole setPath:[bezierPath CGPath]];
    [layerWithHole setFillRule:kCAFillRuleEvenOdd];
    [layerWithHole setFillColor:[[UIColor colorWithWhite:0 alpha:0.35] CGColor]];
    [self.view.layer addSublayer:layerWithHole];
    [self.view.layer setMasksToBounds:YES];
    
    //判断是否相位对焦
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
        AVCaptureDeviceFormat *deviceFormat = _captureDevice.activeFormat;
        if (deviceFormat.autoFocusSystem == AVCaptureAutoFocusSystemPhaseDetection){
            _isFocusPixels = YES;
        }
    }
}

//创建提示信息
- (void)prepareUI
{
    [self.view addSubview:self.topView];
    [self.view addSubview:self.cameraBtn];
    [self.view addSubview:self.backBtn];
    [self.view addSubview:self.changeTypeBtn];
    [self.view addSubview:self.flashBtn];
    [self.view addSubview:self.centerLabel];
    [self.view addSubview:self.scanLine];
    [self.view addSubview:self.promptLabel];
    [self frameSetup];
}

- (void)frameSetup
{
    CGFloat x,y,w,h,ratio = 1;
    if (SCREENW < 400) {
        ratio = SCREENW / 414.;
    }
    
    w = 60 * ratio;
    h = 60 * ratio;
    
    x = SCREENW * 0.5;
    y = SCREENH - h * 0.5 - 20 - SafeAreaBottomHeight;
    
    
    self.cameraBtn.frame = CGRectMake(0, 0, w, h);
    self.cameraBtn.center = CGPointMake(x, y);
    self.flashBtn.frame = CGRectMake(SCREENW - w - 10, SafeAreaTopHeight, w, w);
    self.backBtn.frame = CGRectMake(10, SafeAreaTopHeight, w, h);
    self.changeTypeBtn.frame = CGRectMake(0, 0, w, h);
    self.changeTypeBtn.center = CGPointMake(SCREENW * 0.5, h * 0.5 + SafeAreaTopHeight);
    self.scanLine.transform = CGAffineTransformMakeRotation(M_PI_2);
    
    CGPoint center;
    center.x = CGRectGetMidX(self.topView.squareFrame);
    center.y = CGRectGetMidY(self.topView.squareFrame);
    
    self.centerLabel.frame = CGRectMake(0, 0, 150, 25);
    self.centerLabel.numberOfLines = 0;
    self.centerLabel.center = center;
    self.centerLabel.layer.cornerRadius = self.centerLabel.frame.size.height / 2;
    self.centerLabel.layer.masksToBounds = YES;
    self.centerLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
    
    
    [_promptLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        if (SCREENW == 320) {
            make.top.equalTo(self.view).offset(280);
            make.left.equalTo(self.view).offset(-SCREENH/2 + 2);
        }else if (SCREENW == 375){
            make.top.equalTo(self.view).offset(330);
            make.left.equalTo(self.view).offset(-SCREENH/2 + 5);
        }else{
            make.top.equalTo(self.view).offset(350);
            make.left.equalTo(self.view).offset(-SCREENH/2 + 10);
        }
        make.right.equalTo(self.view).offset(0);
    }];
   self.promptLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
    
}

//监听对焦
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"adjustingFocus"]) {
        _isFocusing =[[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1]];
    }
    if ([keyPath isEqualToString:@"lensPosition"]) {
        _FocusPixelsPosition =[[change objectForKey:NSKeyValueChangeNewKey] floatValue];
    }
}

#pragma mark - 检测

#pragma mark - AVCaptureSession delegate
//从缓冲区获取图像数据进行识别
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (_isPhotoRecog) { // manually photograph
        return ;
    }
    if (_isFocusing) {// is focusing
        return ;
    }
    if (!_isRecognize) {
        return ;
    }
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    UIImage *srcImage = [self imageFromSampleBuffer:sampleBuffer];
    if (_curPosition == _FocusPixelsPosition) {
        //开始识别
        int bSuccess = [_sIDCard recognizeSIDCard:baseAddress Width:(int)width Height:(int)height];
        //识别成功
        if (bSuccess == 0) {
            _isRecognize = NO;
            //震动
            if (self.whetherVibrate) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            }
            //识别结果回调
            dispatch_async(dispatch_get_main_queue(), ^{
                [self recognizeSuccessWithImage:srcImage];
            });
        }
    } else {
        _curPosition = _FocusPixelsPosition;
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}

- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    // Get a CMSampleBuffer‘s Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    //UIImage *image = [UIImage imageWithCGImage:quartzImage];
    UIImage *image = [UIImage imageWithCGImage:quartzImage scale:1.0f orientation:UIImageOrientationUp];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    return (image);
}

- (void)recognizeSuccessWithImage:(UIImage *)image
{
    //识别结果回调
    NSString * isCopy = @"";
    if ([_sIDCard SIDCardCheckIsCopy] == 0) {
        isCopy = @"否";
    } else if ([_sIDCard SIDCardCheckIsCopy] == 1) {
        isCopy = @"是";
    } else {
        isCopy = @"未知";
    }
    if([_sIDCard getRecognizeType] == 1) {
        //正面
        //NSDictionary * resultDic = @{@"姓名":_sIDCard.nsName,@"性别":_sIDCard.nsSex,@"民族":_sIDCard.nsNation,@"出生日期":_sIDCard.nsBirth,@"住址":_sIDCard.nsAddress,@"身份证号":_sIDCard.nsIDNum,@"是否为复印件":isCopy};
        NSDictionary * resultDic = @{@"idCardName":_sIDCard.nsName,@"idCardSex":_sIDCard.nsSex,@"idCardNation":_sIDCard.nsNation,@"idCardBirth":_sIDCard.nsBirth,@"idCardAddress":_sIDCard.nsAddress,@"idCardNum":_sIDCard.nsIDNum,@"idCardIsCopy":isCopy};

        if (self.delegate) {
            if ([self.delegate respondsToSelector:@selector(cameraController:audioRecognizeFinishWithResult:isFrontOrBack:errorCode:andImage:andImageHead:)]) {
                [self.delegate cameraController:self audioRecognizeFinishWithResult:resultDic isFrontOrBack:1 errorCode:0 andImage:_sIDCard.imageCard andImageHead:_sIDCard.imageHead];
            } else {
                NSLog(@"IDCardCamera:cameraController:audioRecognizeFinishWithResult:isFrontOrBack:errorCode:andImage: is unimplemented");
            }
        } else {
            NSLog(@"IDCardCamera:delegate is nil");
        }
        
    }else if([_sIDCard getRecognizeType] == 2){
        //背面
        //NSDictionary * resultDic = @{@"签发机关":_sIDCard.nsIssuingAuthority,@"有效期":_sIDCard.nsExpDate,@"是否为复印件":isCopy};
        NSDictionary * resultDic = @{@"idCardIssuingAuthority":_sIDCard.nsIssuingAuthority,@"idCardExpDate":_sIDCard.nsExpDate,@"idCardIsCopy":isCopy};
        if (self.delegate) {
            if ([self.delegate respondsToSelector:@selector(cameraController:audioRecognizeFinishWithResult:isFrontOrBack:errorCode:andImage:andImageHead:)]) {
                [self.delegate cameraController:self audioRecognizeFinishWithResult:resultDic isFrontOrBack:2 errorCode:0 andImage:_sIDCard.imageCard andImageHead:_sIDCard.imageHead];
            } else {
                NSLog(@"IDCardCamera:cameraController:audioRecognizeFinishWithResult:isFrontOrBack:errorCode:andImage: is unimplemented");
            }
        } else {
            NSLog(@"IDCardCamera:delegate is nil");
        }
    }
}

#pragma mark - 点击事件
//拍照
- (void)captureImage {
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in self.captureOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) { break; }
    }
    
    //get UIImage
    [self.captureOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
        if (imageSampleBuffer == NULL) {
            NSLog(@"imageSampleBuffer is NULL");
            return ;
        }
        //停止取景
        [self.captureSession stopRunning];
        
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
        UIImage *tempImage = [[UIImage alloc] initWithData:imageData];
        UIImage *fullImage = [UIImage imageWithCGImage:tempImage.CGImage scale:1.0 orientation:UIImageOrientationUp];
        
        int nSuccess = [self.sIDCard recognizeSIDCardPhoto:fullImage];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(nSuccess == 0) {
                //manually photograph success
                [self recognizeSuccessWithImage:fullImage];
            } else {
                //manually photograph failed
                if (self.delegate) {
                    if ([self.delegate respondsToSelector:@selector(cameraController:audioRecognizeFinishWithResult:isFrontOrBack:errorCode:andImage:andImageHead:)]) {
                        [self.delegate cameraController:self audioRecognizeFinishWithResult:nil isFrontOrBack:0 errorCode:nSuccess andImage:fullImage andImageHead:fullImage];
                    } else {
                        NSLog(@"IDCardCamera:cameraController:audioRecognizeFinishWithResult:isFrontOrBack:errorCode:andImage: is unimplemented");
                    }
                } else {
                    NSLog(@"IDCardCamera:delegate is nil");
                }
            }
            
        });
    }];
    _isRecognize = NO;
}


//返回按钮点击事件
- (void)backBtnClick {
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(backButtonClickWithIDCardCameraController:)]) {
            [self.delegate backButtonClickWithIDCardCameraController:self];
        }
    } else {
        NSLog(@"IDCameraController:delegate is nil");
    }
    
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

//拍照按钮点击事件
- (void)takePhoto {
    if(_isPhotoRecog){
        [self captureImage];
        if(_flash){
            [self.flashBtn setImage:[self getImageWithName:@"flash_on"] forState:UIControlStateNormal];
            _flash = NO;
        }
    }
}

//闪光灯按钮点击事件
- (void)flashBtnClick {
    
    if (![self.captureDevice hasTorch]) {
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

- (void)changeTypeClick {
    if(_isChangeType){
        self.scanLine.hidden = YES;
        _isPhotoRecog = YES;
        self.centerLabel.text = @"请将证件置于框内再点击拍照按钮";
        self.cameraBtn.hidden = NO;
        _isChangeType = NO;
    }else{
        self.scanLine.hidden = NO;
        _isPhotoRecog = NO;
        self.centerLabel.text = @"请将证件置于框内";
        _isChangeType = YES;
        self.cameraBtn.hidden = YES;
    }
    _isRecognize = YES;
    [self.captureSession startRunning];
}

//移动扫描线
-(void)moveScanline{
    [self.scanLine setCenter:_linePoint];
    [UIView animateWithDuration:4.0f delay:0.0f options:UIViewAnimationOptionRepeat animations:^{
        CGPoint center = self.linePoint;
        center.x -= self.topView.squareFrame.size.width;
        [self.scanLine setCenter:center];
    } completion:^(BOOL finished) {
        
    }];
}


#pragma mark - Motion
- (void)startMotionManager
{
    self.motionManager.deviceMotionUpdateInterval = 1 / 15.0;
    if (self.motionManager.deviceMotionAvailable) {
        //        NSLog(@"Device Motion Available");
        [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler: ^(CMDeviceMotion *motion, NSError *error){
            [self performSelectorOnMainThread:@selector(handleDeviceMotion:) withObject:motion waitUntilDone:YES];
            
        }];
    } else {
        //        NSLog(@"No device motion on device.");
        [self setMotionManager:nil];
    }
}

- (void)handleDeviceMotion:(CMDeviceMotion *)deviceMotion
{
    double x = deviceMotion.gravity.x;
    double y = deviceMotion.gravity.y;
    if (fabs(y) >= fabs(x)) {
        if(_isTransform){
            _isTransform = NO;
            [UIView animateWithDuration:0.5 animations:^{
                self.backBtn.transform = CGAffineTransformMakeRotation(0);
                self.flashBtn.transform = CGAffineTransformMakeRotation(0);
                self.cameraBtn.transform = CGAffineTransformMakeRotation(0);
                self.changeTypeBtn.transform = CGAffineTransformMakeRotation(0);
            } completion:^(BOOL finished) {
                
            }];
        }
    }else{
        if(!_isTransform){
            _isTransform = YES;
            [UIView animateWithDuration:0.5 animations:^{
                self.backBtn.transform = CGAffineTransformMakeRotation(M_PI/2);
                self.flashBtn.transform = CGAffineTransformMakeRotation(M_PI/2);
                self.cameraBtn.transform = CGAffineTransformMakeRotation(M_PI/2);
                self.changeTypeBtn.transform = CGAffineTransformMakeRotation(M_PI/2);
            } completion:^(BOOL finished) {
                
            }];
        }
    }
}

//隐藏状态栏
- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (AVCaptureDevice *)captureDevicePosition:(AVCaptureDevicePosition)position
{
    NSArray * devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice * device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

#pragma mark - 懒加载

#pragma mark 相机相关

- (AVCaptureSession *)captureSession
{
    if (!_captureSession) {
        //创建会话层,视频浏览分辨率为1280*720
        _captureSession = [[AVCaptureSession alloc] init];
        [_captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
    }
    return _captureSession;
}

- (AVCaptureDeviceInput *)captureInput
{
    if (!_captureInput) {
        _captureInput = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice error:nil];
    }
    return _captureInput;
    
}

- (AVCaptureStillImageOutput *)captureOutput
{
    if (!_captureOutput) {
        //创建、配置输出
        _captureOutput = [[AVCaptureStillImageOutput alloc] init];
        NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
        [_captureOutput setOutputSettings:outputSettings];
    }
    return _captureOutput;
}

- (AVCaptureVideoDataOutput *)captureDataOutput
{
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

- (AVCaptureVideoPreviewLayer *)capturePreviewLayer
{
    if (!_capturePreviewLayer) {
        _capturePreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession: self.captureSession];
        _capturePreviewLayer.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
        _capturePreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    return _capturePreviewLayer;
}

- (AVCaptureDevice *)captureDevice
{
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

#pragma mark Motion
- (CMMotionManager *)motionManager
{
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.deviceMotionUpdateInterval = 1/15.0;
    }
    return _motionManager;
}

#pragma mark UI
- (UIButton *)flashBtn
{
    if (!_flashBtn) {
        _flashBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_flashBtn setImage:[self getImageWithName:@"flash_on"] forState:UIControlStateNormal];
        [_flashBtn addTarget:self action:@selector(flashBtnClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _flashBtn;
}

- (UIButton *)backBtn
{
    if (!_backBtn) {
        _backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_backBtn setImage:[self getImageWithName:@"back_btn"] forState:UIControlStateNormal];
        [_backBtn addTarget:self action:@selector(backBtnClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _backBtn;
}

- (UIButton *)cameraBtn
{
    if (!_cameraBtn) {
        _cameraBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage * cameraImage = [self getImageWithName:@"take_pic_btn"];
        [_cameraBtn setImage:cameraImage forState:UIControlStateNormal];
        [_cameraBtn addTarget:self action:@selector(takePhoto) forControlEvents:UIControlEventTouchUpInside];
        _cameraBtn.hidden = YES;
    }
    return _cameraBtn;
}

- (UIButton *)changeTypeBtn
{
    if (!_changeTypeBtn) {
        _changeTypeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_changeTypeBtn setImage:[self getImageWithName:@"change_btn"] forState:UIControlStateNormal];
        [_changeTypeBtn addTarget:self action:@selector(changeTypeClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _changeTypeBtn;
}


- (IDCardSquareView *)topView
{
    if (!_topView) {
        _topView = [[IDCardSquareView alloc] initWithFrame:SCREENRECT];
        _topView.backgroundColor = [UIColor clearColor];
    }
    return _topView;
}

- (UIImageView *)scanLine
{
    if (!_scanLine) {
        CGFloat ratio = [self getRatio];
        _scanLine = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.topView.squareFrame.size.height, 3 * ratio)];
        _scanLine.image = [self getImageWithName:@"scan_line"];
        _scanLine.hidden = NO;
        
        CGPoint center;
        center.x = CGRectGetMidX(_topView.squareFrame);
        center.y = CGRectGetMidY(_topView.squareFrame);
        
        CGPoint top = center;
        top.x += _topView.squareFrame.size.width/2;
        [self.scanLine setCenter:top];
        _linePoint = _scanLine.center;
    }
    return _scanLine;
}

- (UILabel *)centerLabel
{
    if (!_centerLabel) {
        _centerLabel = [[UILabel alloc] init];
        _centerLabel.text = @"请将身份证置于框内";
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
        _promptLabel.text = @"请尽量使用真实身份证，在光线明亮的地方进行扫描";
        _promptLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
        _promptLabel.font = [UIFont fontWithName:@"Helvetica" size:15];
        _promptLabel.textColor = [UIColor whiteColor];
        _promptLabel.backgroundColor = [UIColor clearColor];
        _promptLabel.textAlignment = NSTextAlignmentCenter;
        _promptLabel.hidden = NO;
    }
    return _promptLabel;
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

@end
