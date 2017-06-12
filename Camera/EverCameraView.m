//
//  EverCameraView.m
//  Camera
//
//  Created by Ever on 2017/6/8.
//  Copyright © 2017年 Beijing Byecity International Travel CO., Ltd. All rights reserved.
//

#import "EverCameraView.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

@interface EverCameraView ()<UIGestureRecognizerDelegate,AVCaptureMetadataOutputObjectsDelegate>
{
    NSTimeInterval _focusFaceDuration;
}
@property (nonatomic, copy) ResultBlock resultBlock;

@property (nonatomic, assign) CGFloat effectiveScale; //变焦时，有效缩放比例
@property (nonatomic, assign) CGFloat beginGestureScale;//开始时，缩放比例
@property (nonatomic, assign) CGRect effectiveRect;//有效拍摄区域
@property (nonatomic, assign) BOOL isFocusFace;//是否自动聚焦人脸

//相机相关
@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic, strong) AVCaptureStillImageOutput *imageOutput;
@property (nonatomic, strong) AVCaptureMetadataOutput *metadataOutput;
@property (nonatomic, strong) AVCaptureSession *session;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, strong) CAShapeLayer *effectiveLayer;
@property (nonatomic, strong) CAShapeLayer *maskLayer;

@end

@implementation EverCameraView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        if ([self _isCanUseCamera]) {
            [self _configCarema];
        }
    }
    return self;
}

- (BOOL)isCanUseCamera
{
    return [self _isCanUseCamera];
}

- (void)effectiveRect:(CGRect)rect
{
    self.effectiveRect = rect;
    
    [self.effectiveLayer removeFromSuperlayer];
    [self.maskLayer removeFromSuperlayer];
    
    //设置有效拍着区域
    self.effectiveLayer = [CAShapeLayer layer];
    self.effectiveLayer.path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:6].CGPath;
    self.effectiveLayer.fillColor = [UIColor clearColor].CGColor;
    self.effectiveLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.effectiveLayer.lineDashPattern = @[@4,@4,@5,@6];
    self.effectiveLayer.lineWidth = 2;
    self.effectiveLayer.lineJoin = kCALineJoinRound;
    
    [self.layer addSublayer:self.effectiveLayer];
    
    //设置其他区域黑色半透明遮罩
    self.maskLayer = [CAShapeLayer layer];
    self.maskLayer.path = [self _getMaskPathWithRect:self.previewLayer.bounds exceptRect:rect].CGPath;
    self.maskLayer.fillColor = [UIColor colorWithWhite: 0 alpha: 0.7].CGColor;
    
    [self.layer addSublayer:self.maskLayer];
}

- (void)effectiveRect:(CGRect)rect withImage:(UIImage *)img
{
    self.effectiveRect = rect;
    
    [self.effectiveLayer removeFromSuperlayer];
    [self.maskLayer removeFromSuperlayer];
    
    //设置有效拍着区域
    self.effectiveLayer = [CAShapeLayer layer];
    self.effectiveLayer.frame = self.effectiveRect;
    self.effectiveLayer.contents = (id)img.CGImage;
    [self.layer addSublayer:self.effectiveLayer];
    
    //设置其他区域黑色半透明遮罩
    self.maskLayer = [CAShapeLayer layer];
    self.maskLayer.path = [self _getMaskPathWithRect:self.previewLayer.bounds exceptRect:rect].CGPath;
    self.maskLayer.fillColor = [UIColor colorWithWhite: 0 alpha: 0.7].CGColor;
    
    [self.layer addSublayer:self.maskLayer];
}

- (void)takePhoto:(ResultBlock)block
{
    self.resultBlock = block;
    [self _takePhoto];
}

- (void)openFlash
{
    [self _switchFlash:AVCaptureFlashModeOn];
}

- (void)closeFlash
{
    [self _switchFlash:AVCaptureFlashModeOff];
}

- (void)openTorch
{
    [self _switchTorch:AVCaptureTorchModeOn];
}

- (void)closeTorch
{
    [self _switchTorch:AVCaptureTorchModeOff];
}

- (void)switchFrontCamera
{
    [self _switchCamera:AVCaptureDevicePositionFront];
}

- (void)switchBackCamera
{
    [self _switchCamera:AVCaptureDevicePositionBack];
}

- (void)autoFocusFace:(BOOL)isOpen andDuration:(NSTimeInterval)interval
{
    if (isOpen) {
        _focusFaceDuration = interval;
        _isFocusFace = YES;
        [self _recognizeFaceAndQR];
    }
}

- (void)startRunning
{
    [self.session startRunning];
}

- (void)stopRunning
{
    [self.session stopRunning];
}

#pragma mark - Private API
- (BOOL)_isCanUseCamera
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusDenied) {
        return NO;
    }
    else {
        return YES;
    }
}

#pragma mark - Gesture Action
- (void)tapAction:(UITapGestureRecognizer *)recognizer
{
    CGPoint point = [recognizer locationInView:self];
    
    if (!CGRectContainsPoint(self.effectiveRect, point)) {
        NSLog(@"超出预览层识别区");
        return;
    }
    [self _focusPoint:point];
}

- (void)pinchAction:(UIPinchGestureRecognizer *)recognizer
{
    BOOL isAllTouchesOnThePreviewLayer = YES;
    NSUInteger touchNum = recognizer.numberOfTouches;
    
    //手指必须在预览层才可以生效
    for (int i = 0; i < touchNum; i++)
    {
        CGPoint point = [recognizer locationOfTouch:i inView:self];
        CGPoint newPoint = [self.previewLayer convertPoint:point fromLayer:self.previewLayer.superlayer];
        if (![self.previewLayer containsPoint:newPoint]) {
            isAllTouchesOnThePreviewLayer = NO;
            break;
        }
    }
    
    if (isAllTouchesOnThePreviewLayer) {
        [self _zoom:recognizer.scale];
    }
}

#pragma mark - Private API
- (void)_configCarema
{
    //初始化输入设备
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    
    //初始化输出设备
    self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
    
    //配置Session，连接输入、输出；配置预设大小
    self.session = [[AVCaptureSession alloc] init];
    if ([self.session canSetSessionPreset:AVCaptureSessionPreset1920x1080]) {
        [self.session setSessionPreset:AVCaptureSessionPreset1920x1080];
    }
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    if ([self.session canAddOutput:self.imageOutput]) {
        [self.session addOutput:self.imageOutput];
    }
    
    //配置实时预览层
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.frame = self.bounds;
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer addSublayer:self.previewLayer];
    
    //启动
    [self.session startRunning];
    
    //设置闪光灯、自动白平衡
    if ([self.device lockForConfiguration:nil])
    {
        if ([self.device isFlashModeSupported:AVCaptureFlashModeAuto]) {
            [self.device setFlashMode:AVCaptureFlashModeAuto];
        }
        if ([self.device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
            [self.device setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        }
        [self.device unlockForConfiguration];
    }
    
    //添加点击手势，实现聚焦功能
    UITapGestureRecognizer *focusTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)];
    [self addGestureRecognizer:focusTap];
    
    //添加缩放手势，实现变焦功能
    self.beginGestureScale = 1.0;
    self.effectiveScale = 1.0;
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchAction:)];
    pinch.delegate = self;
    [self addGestureRecognizer:pinch];
}

- (void)_takePhoto
{
    AVCaptureConnection *connection = [self.imageOutput connectionWithMediaType:AVMediaTypeVideo];
    if (connection == nil) {
        NSLog(@"Get AVCaptureConnection failed !!!");
    }
    else {
        __weak typeof(self) weakSelf = self;
        [self.imageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [UIImage imageWithData:data];
            
            if (!CGRectIsEmpty(self.effectiveRect)) {
                image = [self _cutImage:image];
            }
            
            if (weakSelf.resultBlock) {
                weakSelf.resultBlock(image);
            }
            
//            LFCameraResultView *resultView = [[LFCameraResultView alloc] initWithFrame:self.view.bounds];
//            resultView.imageView.image = cutImg;
//            [self.view addSubview:resultView];
        }];
    }
}

//Set the flash
- (void)_switchFlash:(AVCaptureFlashMode)mode
{
    if([self.device lockForConfiguration:nil])
    {
        if ([self.device hasFlash] && [self.device isFlashModeSupported:mode]) {
            [self.device setFlashMode:mode];
        }
        [self.device unlockForConfiguration];
    }
}

//Set the torch
- (void)_switchTorch:(AVCaptureTorchMode)mode
{
    if ([self.device lockForConfiguration:nil]) {
        if ([self.device hasTorch] && [self.device isTorchAvailable]) {
            [self.device setTorchMode:mode];
        }
        [self.device unlockForConfiguration];
    }
}

//Switch camera
- (void)_switchCamera:(AVCaptureDevicePosition)position
{
    [self.session beginConfiguration];
    
    //前后摄像头像素不一样，所以要单独处理下
    if (position == AVCaptureDevicePositionFront) {
        if([self.session canSetSessionPreset:AVCaptureSessionPreset1280x720])
        {
            [self.session setSessionPreset:AVCaptureSessionPreset1280x720];
        }
    }
    else if(position == AVCaptureDevicePositionBack)
    {
        if ([self.session canSetSessionPreset:AVCaptureSessionPreset1920x1080]) {
            [self.session setSessionPreset:AVCaptureSessionPreset1920x1080];
        }
    }
    
    [self.session removeInput:self.input];
    
    NSArray *deviceArray = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in deviceArray)
    {
        if (device.position == position)
        {
            self.device = device;
            break;
        }
    }
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    
    [self.session commitConfiguration];
}

//Focus
- (void)_focusPoint:(CGPoint)point
{
    CGPoint focusPoint;
    
    //    此处自己解释：相机默认横屏，所以如此换算；如果有PreviewLayer ，直接用其换算方法即可；
    //    CGSize size = recognizer.view.bounds.size;
    //    focusPoint = CGPointMake(point.y/size.height, 1 - point.x/size.width);
    focusPoint = [self.previewLayer captureDevicePointOfInterestForPoint:point];
    
    if ([self.device lockForConfiguration:nil])
    {
        if ([self.device isFocusPointOfInterestSupported]) {
            [self.device setFocusPointOfInterest:focusPoint];
            [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([self.device isExposurePointOfInterestSupported]) {
            [self.device setExposurePointOfInterest:focusPoint];
            [self.device setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        
        [self.device unlockForConfiguration];
    }
    
    UIView *focusTipView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 70, 70)];
    focusTipView.center = point;
    focusTipView.backgroundColor = [UIColor clearColor];
    focusTipView.layer.borderColor = [UIColor yellowColor].CGColor;
    focusTipView.layer.borderWidth = 1;
    [self addSubview:focusTipView];
    
    [UIView animateWithDuration:0.3 animations:^{
        focusTipView.transform = CGAffineTransformScale(focusTipView.transform, 1.25, 1.25);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.5 animations:^{
            focusTipView.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            [focusTipView removeFromSuperview];
        }];
    }];
}

//Zoom
- (void)_zoom:(CGFloat)scale
{
    self.effectiveScale = self.beginGestureScale * scale;
    
    if (self.effectiveScale < 1.0) {
        self.effectiveScale = 1.0;
    }
    
    //        CGFloat videoMaxScale = [[self.imageOutput connectionWithMediaType:AVMediaTypeVideo] videoMaxScaleAndCropFactor];
    //        if (self.effectiveScale > videoMaxScale) {
    //            self.effectiveScale = videoMaxScale;
    //        }
    if (self.effectiveScale > 3) {
        self.effectiveScale = 3;
    }
    
    [CATransaction begin];
    CATransaction.animationDuration = 0.25;
    self.previewLayer.affineTransform = CGAffineTransformMakeScale(self.effectiveScale, self.effectiveScale);
    [CATransaction commit];
}

- (UIBezierPath *)_getMaskPathWithRect: (CGRect)rect exceptRect: (CGRect)exceptRect
{
    if (!CGRectContainsRect(rect, exceptRect)) {
        return nil;
    }
    else if (CGRectEqualToRect(rect, CGRectZero)) {
        return nil;
    }
    
    CGFloat boundsInitX = CGRectGetMinX(rect);
    CGFloat boundsInitY = CGRectGetMinY(rect);
    CGFloat boundsWidth = CGRectGetWidth(rect);
    CGFloat boundsHeight = CGRectGetHeight(rect);
    
    CGFloat minX = CGRectGetMinX(exceptRect);
    CGFloat maxX = CGRectGetMaxX(exceptRect);
    CGFloat minY = CGRectGetMinY(exceptRect);
    CGFloat maxY = CGRectGetMaxY(exceptRect);
    CGFloat width = CGRectGetWidth(exceptRect);
    
    /** 添加路径*/
    UIBezierPath * path = [UIBezierPath bezierPathWithRect: CGRectMake(boundsInitX, boundsInitY, minX, boundsHeight)];
    [path appendPath: [UIBezierPath bezierPathWithRect: CGRectMake(minX, boundsInitY, width, minY)]];
    [path appendPath: [UIBezierPath bezierPathWithRect: CGRectMake(maxX, boundsInitY, boundsWidth - maxX, boundsHeight)]];
    [path appendPath: [UIBezierPath bezierPathWithRect: CGRectMake(minX, maxY, width, boundsHeight - maxY)]];
    
    return path;
}

- (UIImage *)_cutImage:(UIImage *)image {
    
    self.effectiveRect = [self.layer convertRect:self.effectiveRect toLayer:self.previewLayer];
    //起点x轴比例
    float orignXRate = self.effectiveRect.origin.x/self.previewLayer.frame.size.width;
    //起点y轴比例
    float orignYRate = self.effectiveRect.origin.y/self.previewLayer.frame.size.height;
    //图片缩放比例
    //    float imageZoomRate = self.previewLayer.frame.size.width/image.size.width;
    float imageZoomRate = image.size.width / self.previewLayer.frame.size.width;
    float orignX = image.size.width * orignXRate;
    float orignY = image.size.height * orignYRate;
    
    CGRect cutImageRect = CGRectZero;
    cutImageRect.origin.x = orignX;
    cutImageRect.origin.y = orignY;
    cutImageRect.size.width = self.effectiveRect.size.width * imageZoomRate;
    cutImageRect.size.height = self.effectiveRect.size.height * imageZoomRate;
    
    //解决上面方法拍照会旋转90度
    CGFloat (^rad)(CGFloat) = ^CGFloat(CGFloat deg) {
        return deg / 180.0f * (CGFloat) M_PI;
    };
    
    CGAffineTransform rectTransform;
    switch (image.imageOrientation) {
        case UIImageOrientationLeft:
            rectTransform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(rad(90)), 0, -image.size.height);
            break;
        case UIImageOrientationRight:
            rectTransform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(rad(-90)), -image.size.width, 0);
            break;
        case UIImageOrientationDown:
            rectTransform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(rad(-180)), -image.size.width, -image.size.height);
            break;
        default:
            rectTransform = CGAffineTransformIdentity;
    };
    
    // adjust the transformation scale based on the image scale
    rectTransform = CGAffineTransformScale(rectTransform, image.scale, image.scale);
    
    // apply the transformation to the rect to create a new, shifted rect
    CGRect transformedCropSquare = CGRectApplyAffineTransform(cutImageRect, rectTransform);
    
    
    CGImageRef imageRef = CGImageCreateWithImageInRect(image.CGImage, transformedCropSquare);
    UIImage *result = [UIImage imageWithCGImage:imageRef scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(imageRef);
    return result;
}

- (void)_recognizeFaceAndQR
{
    [self.session beginConfiguration];
    
    self.metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [self.metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    
    self.metadataOutput.rectOfInterest = CGRectMake(self.effectiveRect.origin.y/self.previewLayer.bounds.size.height, 1 - (self.effectiveRect.origin.x + self.effectiveRect.size.width)/self.previewLayer.bounds.size.width, self.effectiveRect.size.height/self.previewLayer.bounds.size.height, self.effectiveRect.size.width/self.previewLayer.bounds.size.width);
    
    if ([self.session canAddOutput:self.metadataOutput]) {
        [self.session addOutput:self.metadataOutput];
        self.metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeQRCode,AVMetadataObjectTypeFace];
    }
    
    [self.session commitConfiguration];
}

- (void)_latestImageInAlbum {
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    PHFetchResult *assetsFetchResults = [PHAsset fetchAssetsWithOptions:options];
    PHAsset *asset = [assetsFetchResults firstObject];
    
    PHCachingImageManager *imageManager = [[PHCachingImageManager alloc] init];
    [imageManager requestImageForAsset:asset targetSize:CGSizeZero contentMode:PHImageContentModeDefault options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        if (result) {
//            [self buildBottomView:result];
        }
        else {
//            [self buildBottomView:nil];
        }
    }];
}


#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
        self.beginGestureScale = self.effectiveScale;
    }
    NSLog(@"%f",self.beginGestureScale);
    return YES;
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (metadataObjects.count > 0)
    {
        //        [self.session stopRunning];
        NSLog(@"%@",metadataObjects);
        AVMetadataMachineReadableCodeObject *metadata = [metadataObjects objectAtIndex:0];
        if ([metadata.type isEqualToString:AVMetadataObjectTypeFace])
        {
            AVMetadataObject *objc = [self.previewLayer transformedMetadataObjectForMetadataObject:metadata];
            NSLog(@"objc:%@",objc);
            
            NSLog(@"metadata:%@",metadata);
            
            if (self.isFocusFace) //防止短时间内，一直不断的聚焦人脸
            {
                self.isFocusFace = NO;
                [self _focusPoint:CGPointMake(CGRectGetMidX(objc.bounds), CGRectGetMidY(objc.bounds))];
                [self performSelector:@selector(receiveFocus) withObject:nil afterDelay:_focusFaceDuration];
            }
        }
        else if([metadata.type isEqualToString:AVMetadataObjectTypeQRCode])
        {
            NSLog(@"QR-Code:%@",metadata.stringValue);
        }
    }
}

- (void)receiveFocus
{
    self.isFocusFace = YES;
}

@end
