#import "FlutterPlugin.h"
#import "BankCardCameraController.h"
#import "IDCardCameraController. h"
#import "UIView+Toast.h"

@interface FlutterPlugin () <IDCardCameraDelegate,CameraDelegate>

@property (nonatomic, strong) FlutterResult result;
@property (nonatomic, strong) NSString *isIdCardFront;//1正面 2反面

@end

@implementation FlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"flutter_plugin"
            binaryMessenger:[registrar messenger]];
  FlutterPlugin* instance = [[FlutterPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  self.result = result;
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else if ([@"getBankCard" isEqualToString:call.method]) {
    [self savefile];
    self.controller = (FlutterViewController *)[UIApplication sharedApplication].keyWindow.rootViewController;
    BankCardCameraController *vc = [[BankCardCameraController alloc] init];
    vc.delegate = self;
    [self.controller presentViewController:vc animated:YES completion:nil];
  } else if ([@"getIdCardFront" isEqualToString:call.method] ||
             [@"getIdCardBack" isEqualToString:call.method]) {
      if ([@"getIdCardFront" isEqualToString:call.method]) {
          self.isIdCardFront = @"1";
      } else {
          self.isIdCardFront = @"2";
      }
    [self savefile];
    self.controller = (FlutterViewController *)[UIApplication sharedApplication].keyWindow.rootViewController;
    IDCardCameraController *vc = [[IDCardCameraController alloc] init];
    vc.delegate = self;
    vc.whetherVibrate = YES;
    [self.controller presentViewController:vc animated:YES completion:nil];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

#pragma mark - CameraDelegate
- (void)initBankCardWithResult:(int)nInit
{
    if (nInit != 0) {
       NSString *errorString = [NSString stringWithFormat:@"初始化失败，错误代码%d", nInit];
      [self.controller.view makeToast:errorString duration:2.0f position:CSToastPositionCenter];
    }
}

- (void)getBankCardInfo:(NSDictionary *)bankCardInfo
{
    NSString *cardNo = [bankCardInfo objectForKey:@"bankNo"];
    UIImage *bankCardImg = [bankCardInfo objectForKey:@"bankCardImg"];
    [self saveImage:bankCardImg withName:@"bankCardImg"];
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    [dic setObject:cardNo forKey:@"bankCardNo"];
    [dic setObject:[self getImagePathWithName:@"bankCardImg"] forKey:@"bankCardImgPath"];
    self.result([self convert2JSONWithDictionary:dic]);
}

#pragma mark -- IDCardCameraDelegate
//MARK:视频流识别回调
- (void)cameraController:(UIViewController *)cameraController audioRecognizeFinishWithResult:(NSDictionary *)resultDic isFrontOrBack:(int)frontOrBack errorCode:(int)errorCode andImage:(UIImage *)cardImage andImageHead:(UIImage *)imageHead
{
    if (errorCode == 0) {//recognize success
        if ([self.isIdCardFront isEqualToString:@"1"]) {//身份证正面
            if (frontOrBack == 1) {
                [self saveImage:cardImage withName:@"cardImageFont"];
                NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:resultDic];
                [dic setObject:[self getImagePathWithName:@"cardImageFont"] forKey:@"cardImageFontPath"];
                self.result([self convert2JSONWithDictionary:dic]);
            } else {
                NSString *errorString = [NSString stringWithFormat:@"请拍摄身份证正面"];
                [self.controller.view makeToast:errorString duration:2.0f position:CSToastPositionCenter];
            }
        } else {//身份证反面
            if (frontOrBack == 2) {
                [self saveImage:cardImage withName:@"cardImageBack"];
                NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:resultDic];
                [dic setObject:[self getImagePathWithName:@"cardImageBack"] forKey:@"cardImageBackPath"];
                self.result([self convert2JSONWithDictionary:dic]);
            } else {
                NSString *errorString = [NSString stringWithFormat:@"请拍摄身份证反面"];
                [self.controller.view makeToast:errorString duration:2.0f position:CSToastPositionCenter];
            }
        }
        
    } else { //recognize failed
        NSString *errorString = [NSString stringWithFormat:@"识别失败，错误代码%d", errorCode];
        [self.controller.view makeToast:errorString duration:2.0f position:CSToastPositionCenter];
    }
    [self didCancel];
}

-(void)didCancel
{
    [self.controller dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 保存lic文件到沙盒
- (void)savefile
{
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSURL *bundleURL = [[NSBundle mainBundle] URLForResource:@"Frameworks" withExtension:nil];
    bundleURL = [bundleURL URLByAppendingPathComponent:@"flutter_plugin"];
    bundleURL = [bundleURL URLByAppendingPathExtension:@"framework"];
    NSBundle *bunle = [NSBundle bundleWithURL:bundleURL];
    //lic路径
    NSString * licFromPath = [bunle pathForResource:@"947C5EC227912874BCB9.lic" ofType:@""];
    NSLog(@"FromPath：%@", licFromPath);
    if (![fileManager fileExistsAtPath:licFromPath]) {
        NSLog(@"can't find lic");
        return;
    }
    //沙盒Documents路径
    NSString * docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    //目标位置：Documents路径+授权文件名
    NSString * licToPath = [docDir stringByAppendingPathComponent:@"947C5EC227912874BCB9.lic"];
    NSLog(@"ToPath：%@", licToPath);
    //先检查是否存在。
    if (![fileManager fileExistsAtPath:licToPath]) {
        //开始复制lic
        NSError *err = nil;
        [[NSFileManager defaultManager] copyItemAtPath:licFromPath toPath:licToPath error:&err];
        if (err) {
            NSLog(@"lic copy error:%@",err);
        }
    }
}

- (NSString *)convert2JSONWithDictionary:(NSDictionary *)dic
{
    NSError *err;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:&err];

    NSString *jsonString;
    if (!jsonData) {
        NSLog(@"%@",err);
    }else{
        jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    NSLog(@"%@",jsonString);
    return jsonString;
}

- (void)saveImage:(UIImage *)image withName:(NSString *)imageName
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *filePath = [[paths objectAtIndex:0]stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.png", imageName]];  // 保存文件的名称
    BOOL result =[UIImagePNGRepresentation(image)writeToFile:filePath atomically:YES]; // 保存成功会返回YES
    if (result == YES) {
        NSLog(@"保存成功");
    }
}

- (NSString *)getImagePathWithName:(NSString *)imageName
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
    
    NSString *filePath = [[paths objectAtIndex:0]stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.png", imageName]];
    
    return filePath;
}
@end
