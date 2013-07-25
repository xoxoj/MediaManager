//
//  KNVideoManager.h
//  iMultiviewCPSLib
//
//  Created by ken on 13. 5. 22..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "Global.h"

typedef enum {
    kKNGravityResizeToFit,
    kKNGravityAspectFill,
    kKNGravityAspectFit
}KNPreviewGravity;

typedef enum {
    kKNCameraFront,
    kKNCameraBack,
    kKNCameraOff,
}KNCameraPosition;


typedef enum {
    kKNCaptureHigh,
    kKNCaptureMedium,
    kKNCaptureLow,
    kKNCapture288,
    kKNCapture480,
    kKNCapture720,
    kKNCapture1080
}KNCaptureResolution;

typedef enum {
    kKNRawDataRGB32,
    kKNRawDataYUV420Planar
}KNRawDataType;


@class KNImageConvert;
@interface KNVideoManager : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (readonly) KNCameraPosition cameraPosition;
@property (assign, nonatomic) KNVideoVideoOrientation videoOrientation;
@property CGSize captureSize;


- (id)initWidthImageConvert:(KNImageConvert *)convert;

- (void)startVideoWithPreview:(UIView *)preview
                    frameRate:(NSInteger)frameRate
                   resolution:(KNCaptureResolution)resolution
                  captureType:(KNRawDataType)rawDataType
                    mirroring:(BOOL)mirror
                captureOutput:(void(^)(uint8_t* data, int len))captureOutBlock
                previewRender:(void(^)(uint8_t* data, int w, int h))previwBlock;

- (void)stopVideo;

- (void)previewVideoGravity:(KNPreviewGravity)gravity;

- (void)changeCameraPosition:(KNCameraPosition)cameraPosition;

- (BOOL)changeCaptureResolution:(KNCaptureResolution)resolution;

- (void)changeCaptureFrameRate:(NSInteger)framerate;

- (void)torchToggle;
- (void)setAutoTorchMode:(BOOL)use;
- (void)setTorchLevel:(float)level;
- (BOOL)isMirroring;
- (void)setMirroring:(BOOL)mirror;

@end
