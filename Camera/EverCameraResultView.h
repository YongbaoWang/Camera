//
//  EverCameraResultView.h
//  Camera
//
//  Created by Ever on 2017/6/12.
//  Copyright © 2017年 Beijing Byecity International Travel CO., Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EverCameraResultView : UIView

@property (strong, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) UIButton *btRephotograph;
@property (strong, nonatomic) UIButton *btUsePhoto;
@property (copy, nonatomic) void (^rephotographBlock)();//重拍
@property (copy, nonatomic) void (^usePhotoBlock)(UIImage *img);//使用

@end
