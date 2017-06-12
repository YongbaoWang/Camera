//
//  EverCameraResultView.m
//  Camera
//
//  Created by Ever on 2017/6/12.
//  Copyright © 2017年 Beijing Byecity International Travel CO., Ltd. All rights reserved.
//

#import "EverCameraResultView.h"

@implementation EverCameraResultView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initUI];
    }
    return self;
}

-(void)layoutSubviews {
    [super layoutSubviews];
    self.imageView.frame = self.bounds;
    self.btRephotograph.frame = CGRectMake(20, self.frame.size.height - 60, 60, 40);
    self.btUsePhoto.frame = CGRectMake(self.frame.size.width - 80, self.frame.size.height - 60, 60, 40);
}

- (void)initUI {
    
    self.imageView = [[UIImageView alloc] initWithFrame:self.bounds];
    self.imageView.backgroundColor =[UIColor blackColor];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:self.imageView];
    
    self.btRephotograph = [[UIButton alloc] initWithFrame:CGRectMake(20, self.frame.size.height - 60, 60, 40)];
    [self.btRephotograph setTitle:@"重拍" forState:UIControlStateNormal];
    [self.btRephotograph addTarget:self action:@selector(rephotograph:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.btRephotograph];
    
    self.btUsePhoto = [[UIButton alloc] initWithFrame:CGRectMake(self.frame.size.width - 80, self.frame.size.height - 60, 60, 40)];
    [self.btUsePhoto setTitle:@"使用" forState:UIControlStateNormal];
    [self.btUsePhoto addTarget:self action:@selector(usePhoto:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.btUsePhoto];
}

- (void)rephotograph:(id)sender {
    [self removeFromSuperview];
    if (self.rephotographBlock) {
        self.rephotographBlock();
    }
}

- (void)usePhoto:(id)sender {
    if (self.usePhotoBlock) {
        self.usePhotoBlock(self.imageView.image);
    }
}

@end
