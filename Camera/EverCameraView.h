//
//  EverCameraView.h
//  Camera
//
//  Created by Ever on 2017/6/8.
//  Copyright © 2017年 Beijing Byecity International Travel CO., Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^ResultBlock)(UIImage *image);

@interface EverCameraView : UIView

/**
 初始化

 @param frame frame
 @return 实例
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 设置有效取景区
 
 @param rect Frame
 */
- (void)effectiveRect:(CGRect)rect;

/**
 通过设置图片，来设置有效取景区
 
 @param img 建议中间透明的图片
 */
- (void)effectiveRect:(CGRect)rect withImage:(UIImage *)img;

/**
 相机是否可用

 @return Bool
 */
- (BOOL)isCanUseCamera;

/**
 拍照

 @param block 拍照完成后，回传图片
 */
- (void)takePhoto:(ResultBlock)block;

/**
 打开闪光灯
 */
- (void)openFlash;

/**
 关闭闪光灯
 */
- (void)closeFlash;

/**
 打开手电筒
 */
- (void)openTorch;

/**
 关闭手电筒
 */
- (void)closeTorch;

/**
 开启前置摄像头
 */
- (void)switchFrontCamera;

/**
 开启后置摄像头
 */
- (void)switchBackCamera;

/**
 是否开启自动对焦人脸功能

 @param isOpen 是否开启
 @param interval 重复对焦间隔时间
 */
- (void)autoFocusFace:(BOOL)isOpen andDuration:(NSTimeInterval)interval;

/**
 开始取景
 */
- (void)startRunning;

/**
 停止取景
 */
- (void)stopRunning;

@end
