//
//  SquareView.m
//  SBankCardDemo
//
//  Created by ocrgroup on 2017/9/27.
//  Copyright © 2017年 ocrgroup. All rights reserved.
//

#import "SquareView.h"
#import "BankCardCameraController.h"

//长宽是固定的
#define VIEWHEIGHT 514
#define VIEWWIDTH 325
#define LINELENGTH 20

#define SCREENW [UIScreen mainScreen].bounds.size.width
#define SCREENH [UIScreen mainScreen].bounds.size.height

@interface SquareView ()

//竖屏情况下的宽高
@property (nonatomic, assign) CGFloat viewHeight;
@property (nonatomic, assign) CGFloat viewWidth;

@end

@implementation SquareView {
    //无论横屏还是竖屏计算得到的都是以竖屏为准的四个顶点
    CGPoint leftTop;  //竖屏左上角顶点
    CGPoint leftBottom; //竖屏左下角顶点
    CGPoint rightBottom; //竖屏右下角顶点
    CGPoint rightTop;  //竖屏右上角顶点
    
    NSInteger _direction;
    
}

- (instancetype)initWithDirection:(NSInteger)direction {
    self = [super init];
    if (self) {
        _direction = direction;
        if (direction == kAudioDirectionHorizontal) {
            //横屏
            self.viewHeight = 514;
            self.viewWidth = 325;
            
            //判断是否为4,4s,5s,5c,6,6s
            if (SCREENW < 400) {
                //根据固定的长宽和传入的frame计算四个角的位置
                CGFloat x,y,newW,newH,ratio;
                ratio = SCREENW / 414;
                newW = self.viewWidth * ratio * 0.85;
                newH = self.viewHeight * ratio * 0.85;
                
                x = (SCREENW - newW) * 0.5;
                y = (SCREENH - newH) * 0.5;
                leftTop = CGPointMake(x , y);
                leftBottom = CGPointMake(x, y + newH);
                rightTop = CGPointMake(x + newW , y);
                rightBottom = CGPointMake(x + newW , y + newH);
                
                self.squareFrame = CGRectMake(x, y, newW, newH);
            }else if(SCREENW > 414){
                //pad
                //根据固定的长宽和传入的frame计算四个角的位置
                CGFloat x,y,newW,newH,ratio;
                ratio = SCREENW / 414;
                newW = self.viewWidth * 1.3;
                newH = self.viewHeight * 1.3;
                
                x = (SCREENW - newW) * 0.5;
                y = (SCREENH - newH) * 0.5;
                leftTop = CGPointMake(x , y);
                leftBottom = CGPointMake(x, y + newH);
                rightTop = CGPointMake(x + newW , y);
                rightBottom = CGPointMake(x + newW , y + newH);
                
                self.squareFrame = CGRectMake(x, y, newW, newH);
            }else{
                //根据固定的长宽和传入的frame计算四个角的位置
                CGFloat x,y;
                x = (SCREENW - self.viewWidth) * 0.5;
                y = (SCREENH - self.viewHeight) * 0.5;
                leftTop = CGPointMake(x , y);
                leftBottom = CGPointMake(x, y + self.viewHeight);
                rightTop = CGPointMake(x + self.viewWidth , y);
                rightBottom = CGPointMake(x + self.viewWidth , y + self.viewHeight);
                
                self.squareFrame = CGRectMake(x, y, self.viewWidth, self.viewHeight);
            }
            
        }else{
            //竖屏
            if (SCREENW > 414) {//pad
                //根据固定的长宽和传入的frame计算四个角的位置
                self.viewWidth = SCREENW - 100;
                self.viewHeight = (SCREENW - 100) / 514. * 325;
                
            }else{//手机,和屏幕等宽
                self.viewWidth = SCREENW;
                self.viewHeight = SCREENW / 514. * 325;
            }
            CGFloat x,y;
            x = (SCREENW - self.viewWidth) * 0.5;
            y = (SCREENH - self.viewHeight) * 0.5;
            leftTop = CGPointMake(x , y);
            leftBottom = CGPointMake(x, y + self.viewHeight);
            rightTop = CGPointMake(x + self.viewWidth , y);
            rightBottom = CGPointMake(x + self.viewWidth , y + self.viewHeight);
            
            self.squareFrame = CGRectMake(x, y, self.viewWidth, self.viewHeight);
            
        }
        
    }
    return self;
}

//默认为屏幕的长宽
//- (instancetype)init
//{
//    self = [super init];
//    if (self) {
//        //判断是否为4,4s,5s,5c,6,6s
//        if (SCREENW < 400) {
//            //根据固定的长宽和传入的frame计算四个角的位置
//            CGFloat x,y,newW,newH,ratio;
//            ratio = SCREENW / 414;
//            newW = VIEWWIDTH * ratio;
//            newH = VIEWHEIGHT * ratio;
//
//            x = (SCREENW - newW) * 0.5;
//            y = (SCREENH - newH) * 0.5;
//            leftTop = CGPointMake(x , y);
//            leftBottom = CGPointMake(x, y + newH);
//            rightTop = CGPointMake(x + newW , y);
//            rightBottom = CGPointMake(x + newW , y + newH);
//
//            self.squareFrame = CGRectMake(x, y, newW, newH);
//        }else{
//            //根据固定的长宽和传入的frame计算四个角的位置
//            CGFloat x,y;
//            x = (SCREENW - VIEWWIDTH) * 0.5;
//            y = (SCREENH - VIEWHEIGHT) * 0.5;
//            leftTop = CGPointMake(x , y);
//            leftBottom = CGPointMake(x, y + VIEWHEIGHT);
//            rightTop = CGPointMake(x + VIEWWIDTH , y);
//            rightBottom = CGPointMake(x + VIEWWIDTH , y + VIEWHEIGHT);
//
//            self.squareFrame = CGRectMake(x, y, VIEWWIDTH, VIEWHEIGHT);
//        }
//
//    }
//    return self;
//}

//如果传入了frame,则忽略,还按照屏幕size计算
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        //判断是否为4,4s,5s,5c,6,6s
        if (SCREENW < 400) {
            //根据固定的长宽和传入的frame计算四个角的位置
            CGFloat x,y,newW,newH,ratio;
            ratio = SCREENW / 414;
            newW = VIEWWIDTH * ratio;
            newH = VIEWHEIGHT * ratio;
            
            x = (SCREENW - newW) * 0.5;
            y = (SCREENH - newH) * 0.5;
            leftTop = CGPointMake(x , y);
            leftBottom = CGPointMake(x, y + newH);
            rightTop = CGPointMake(x + newW , y);
            rightBottom = CGPointMake(x + newW , y + newH);
            
            self.squareFrame = CGRectMake(x, y, newW, newH);
        }else{
            //根据固定的长宽和屏幕长宽计算四个角的位置
            CGFloat x,y;
            x = (SCREENW - VIEWWIDTH) * 0.5;
            y = (SCREENH - VIEWHEIGHT) * 0.5;
            leftTop = CGPointMake(x , y);
            leftBottom = CGPointMake(x, y + VIEWHEIGHT);
            rightTop = CGPointMake(x + VIEWWIDTH , y);
            rightBottom = CGPointMake(x + VIEWWIDTH , y + VIEWHEIGHT);
            
            self.squareFrame = CGRectMake(x, y, VIEWWIDTH, VIEWHEIGHT);
        }
        
    }
    return self;
}


- (void) drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    //    [[UIColor colorWithRed:1.0 green:0.5 blue:0.0 alpha:1.0] set];
    [[UIColor greenColor] set];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    //设置线宽
    CGContextSetLineWidth(context, 2.0f);
    //画角线
    CGContextMoveToPoint(context,leftTop.x, leftTop.y+20);
    CGContextAddLineToPoint(context, leftTop.x, leftTop.y);
    CGContextAddLineToPoint(context, leftTop.x+20, leftTop.y);
    
    CGContextMoveToPoint(context, rightTop.x - 20,rightTop.y);
    CGContextAddLineToPoint(context, rightTop.x,rightTop.y);
    CGContextAddLineToPoint(context, rightTop.x,rightTop.y + 20);
    
    CGContextMoveToPoint(context, leftBottom.x,leftBottom.y - 20);
    CGContextAddLineToPoint(context, leftBottom.x,leftBottom.y);
    CGContextAddLineToPoint(context, leftBottom.x + 20,leftBottom.y);
    
    CGContextMoveToPoint(context, rightBottom.x - 20, rightBottom.y);
    CGContextAddLineToPoint(context, rightBottom.x, rightBottom.y);
    CGContextAddLineToPoint(context, rightBottom.x, rightBottom.y - 20);
    CGContextStrokePath(context);
    
    [[UIColor whiteColor] set];
    context = UIGraphicsGetCurrentContext();
    //设置线宽
    CGContextSetLineWidth(context, 0.2f);
    //画边线
    CGContextMoveToPoint(context,leftBottom.x, leftBottom.y);
    CGContextAddLineToPoint(context, rightBottom.x, rightBottom.y);
    CGContextAddLineToPoint(context, rightTop.x, rightTop.y);
    CGContextAddLineToPoint(context, leftTop.x, leftTop.y);
    CGContextAddLineToPoint(context, leftBottom.x, leftBottom.y);
    CGContextStrokePath(context);
}

@end
