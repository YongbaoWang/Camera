//
//  ViewController.m
//  Camera
//
//  Created by Ever on 2017/6/8.
//  Copyright © 2017年 Beijing Byecity International Travel CO., Ltd. All rights reserved.
//

#import "ViewController.h"
#import "EverCameraView.h"
#import "EverCameraResultView.h"

@interface ViewController ()

@property (nonatomic, strong) EverCameraView *cameraView;

@end

@implementation ViewController

#pragma mark - View Life
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.cameraView = [[EverCameraView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    
    CGFloat effectiveWidth = [UIScreen mainScreen].bounds.size.width - 46 * 2;
    [self.cameraView effectiveRect:CGRectMake(46, 124, effectiveWidth, effectiveWidth * 1.4) withImage:[UIImage imageNamed:@"mask_passport"]];
    [self.cameraView autoFocusFace:YES andDuration:2];
    [self.view insertSubview:self.cameraView atIndex:0];
    [self.cameraView startRunning];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBAction
- (IBAction)flashAction:(UIButton *)sender {
    if (sender.isSelected)
    {
        [self.cameraView closeFlash];
    }
    else {
        [self.cameraView openFlash];
    }
    sender.selected = !sender.isSelected;
}

- (IBAction)albumAction:(UIButton *)sender {
    
}

- (IBAction)takePhotoAction:(id)sender {
    [self.cameraView takePhoto:^(UIImage *image) {
        EverCameraResultView *resultView = [[EverCameraResultView alloc] initWithFrame:self.view.bounds];
        resultView.imageView.image = image;
        [self.view addSubview:resultView];
    }];
}

@end
