//
//  MeidaManagerParam.m
//  MediaManager
//
//  Created by cyh on 7/27/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import "MediaVideoParam.h"

@interface MediaVideoParam () {
    blockEncOutput blkEncOutput_;
//    blockDecOutput blkDecOutput_;
}
@end

@implementation MediaVideoParam

@synthesize viewPreview             = _viewPreview;
@synthesize viewPeerview            = _viewPeerview;
@synthesize encVideoCodec           = _encVideoCodec;
@synthesize decVideoCodec           = _decVideoCodec;
@synthesize captureResolution       = _captureResolution;
@synthesize captureOrientation      = _captureOrientation;
@synthesize captureFPS              = _captureFPS;
@synthesize packetizeMode           = _packetizeMode;
@synthesize appendRtpHeader         = _appendRtpHeader;
@synthesize captureSize             = _captureSize;


- (void)dealloc {
    
    [_viewPreview release];
    [_viewPeerview release];
    
    if (blkEncOutput_) {
        [blkEncOutput_ release];
        blkEncOutput_ = nil;
    }
    
//    if (blkDecOutput_) {
//        [blkDecOutput_ release];
//        blkDecOutput_ = nil;
//    }

    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self) {
        _captureSize = CGSizeZero;
    }
    return self;
}

- (void)setEncOuputBlock:(blockEncOutput)encOut {
    
    if (blkEncOutput_) {
        [blkEncOutput_ release];
    }
    blkEncOutput_ = [encOut copy];
}

- (blockEncOutput)getEncOuputBlock {
    return blkEncOutput_;
}

//- (void)setDecOuputBlock:(blockDecOutput)decOut {
//
//    if (blkDecOutput_) {
//        [blkDecOutput_ release];
//    }
//    blkDecOutput_ = [decOut copy];
//}
//
//- (blockDecOutput)detDecOuputBlock {
//    return blkDecOutput_;
//}

- (NSString *)description {
    return nil;
}


#pragma mark - Public
- (CGSize)getOrientationCaptureSize {
    
    CGSize capSize;
    
    if (_captureResolution == kKNCaptureLow) {
        capSize = CGSizeMake(192, 144);
    } else if (_captureResolution == kKNCaptureMedium) {
        capSize = CGSizeMake(480, 360);
    } else if (_captureResolution == kKNCaptureHigh) {
        capSize = CGSizeMake(640, 480);
    } else if (_captureResolution == kKNCapture288) {
        capSize = CGSizeMake(352, 288);
    } else if (_captureResolution == kKNCapture480) {
        capSize = CGSizeMake(640, 480);
    } else if (_captureResolution == kKNCapture720) {
        capSize = CGSizeMake(1280, 720);
    } else if (_captureResolution == kKNCapture1080) {
        capSize = CGSizeMake(1920, 1080);
    } else {
        capSize = CGSizeMake(192, 144);
    }
    _captureSize = capSize;
    if (_captureOrientation == kKNVideoOrientationPortrait) {
        float tmp = capSize.width;
        capSize.width = capSize.height;
        capSize.height = tmp;
    }
    
    NSLog(@"Capture Size : %dx%d", (int)_captureSize.width, (int)_captureSize.height);

    return capSize;
}

@end
