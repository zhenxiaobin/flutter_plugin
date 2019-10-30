#import <Flutter/Flutter.h>
#import <UIKit/UIKit.h>

@interface FlutterPlugin : NSObject<FlutterPlugin>

@property (nonatomic, strong) FlutterViewController *controller;

@end
