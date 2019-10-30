//
//  SquareView.h
//  SBankCardDemo
//
//  Created by ocrgroup on 2017/9/27.
//  Copyright © 2017年 ocrgroup. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SquareView : UIView

@property (assign ,nonatomic) CGRect squareFrame;  //检测区域

- (instancetype)initWithDirection:(NSInteger)direction;

@end
