//
//  KNImageConvert.m
//  iMultiviewCPSLib
//
//  Created by ken on 13. 5. 30..
//  Copyright (c) 2013년 SH. All rights reserved.
//
//    I420Scale(yuv420pBuffer_, height, yuv420pBuffer_ + ysize, height / 2, yuv420pBuffer_ + ysize + uvsize, height / 2, height, width,
//              secondBuffer_, width, secondBuffer_ + ysize, width  / 2, secondBuffer_ + ysize + uvsize, width / 2, width, height, kFilterBilinear);

//    NV12ToI420(yPlaneAddress, yPixelCount, uvPlaneAddress, uvPixelCount,
//               yuv420pBuffer_, width, yuv420pBuffer_ + ysize, width / 2, yuv420pBuffer_ + ysize + uvsize, width / 2,
//               width, height);
//
//    I420Mirror(yuv420pBuffer_, height, yuv420pBuffer_ + ysize, height / 2, yuv420pBuffer_ + ysize + uvsize, height / 2,
//               secondBuffer_, height, secondBuffer_ + ysize, height / 2, secondBuffer_ + ysize + uvsize, height / 2, height, width);
//
//    I420Rotate(secondBuffer_, width, secondBuffer_ + ysize, width / 2, secondBuffer_ + ysize + uvsize, width / 2,
//               yuv420pBuffer_, height, yuv420pBuffer_ + ysize, height / 2, yuv420pBuffer_ + ysize + uvsize, height / 2, width, height, kRotate270);


#import "KNImageConvert.h"
#import "libyuv.h"

@interface KNImageConvert ()
@property (assign) uint8_t* mainBuffer;
@property (assign) uint8_t* scaleBuffer;
@property (assign) uint8_t* mirrorBuffer;
@property (assign) int scaleWidth;
@property (assign) int scaleHeight;
@end


@implementation KNImageConvert

@synthesize bufferSize      = _bufferSize;
@synthesize mainBuffer      = _mainBuffer;
@synthesize scaleBuffer     = _scaleBuffer;
@synthesize mirrorBuffer    = _mirrorBuffer;
@synthesize width           = _width;
@synthesize height          = _height;
@synthesize scaleWidth      = _scaleWidth;
@synthesize scaleHeight     = _scaleHeight;


- (void)dealloc {
    
    if (_mainBuffer) {
        free(_mainBuffer);
        _mainBuffer = NULL;
    }
    
    if (_scaleBuffer) {
        free(_scaleBuffer);
        _scaleBuffer = NULL;
    }
    
    if (_mirrorBuffer) {
        free(_mirrorBuffer);
        _mirrorBuffer = NULL;
    }

    _bufferSize = 0;
    
    [super dealloc];
}

- (id)initWidthWidth:(int)w height:(int)h {

    self = [super init];
    if (self) {
        
        _width  = w;
        _height = h;
        
        _bufferSize = (w * h * 3) >> 1;
        
        _mainBuffer = (uint8_t *)malloc(sizeof(uint8_t) * _bufferSize);
        
        NSLog(@"@KNImageConvert buffersize : %d.", _bufferSize);
    }
    return self;
}

- (uint8_t *)rgb32ToI420Rotate:(uint8_t *)rgbBuffer size:(int)size rotate:(KNImageRotate)r {
    
    int targetW = _width;
    int targetH = _height;
    int targetLineSize = _width;
    
    if ( (r == kKnImageRotate90) || (r == kKnImageRotate270)) {
        float rate =  _height / (float)_width;
        targetW = _height;
        targetH = (int)(targetW * rate);
        if (targetH % 2 != 0)
            targetH -= 1;
        
        targetLineSize = targetH;
    }
    int ysize = targetW * targetH;
    int uvsize = ysize / 4;

    
    ConvertToI420(rgbBuffer, size,
                  _mainBuffer, targetLineSize, _mainBuffer + ysize, targetLineSize / 2, _mainBuffer + ysize + uvsize, targetLineSize / 2,
                  (_width - targetW)/2 , (_height - targetH)/2,
                  _width, _height,
                  targetW, targetH,
                  (enum RotationMode)r, FOURCC_ARGB);
    
    return _mainBuffer;
}

- (uint8_t *)I420Scale:(uint8_t*)yuvBuffer srcW:(int)srcW srcH:(int)srcH dstW:(int)dstW dstH:(int)dstH roatated:(BOOL)isRorated {
    
    if (isRorated) {
        int tmp = srcW;
        srcW = srcH;
        srcH = tmp;
    }

    int ysize1 = srcW * srcH;
    int uvsize1 = ysize1 / 4;

    int ysize2 = dstW * dstH;
    int uvsize2 = ysize2 / 4;
    
    if (!_scaleBuffer || (_scaleWidth != dstW)) {
        if (_scaleBuffer) {
            free(_scaleBuffer);
        }
        _scaleBuffer = (uint8_t *)malloc(sizeof(uint8_t) * ((dstW * dstH * 3) >> 1));
        
        _scaleWidth = dstW;
        _scaleHeight = dstH;
    }

    
    I420Scale(yuvBuffer, srcW, yuvBuffer + ysize1, srcW / 2, yuvBuffer + ysize1 + uvsize1, srcW / 2, srcW, srcH,
              _scaleBuffer, dstW, _scaleBuffer + ysize2, dstW  / 2, _scaleBuffer + ysize2 + uvsize2, dstW / 2, dstW, dstH, kFilterBox);
    
    return _scaleBuffer;
}

- (uint8_t *)YUV420PlaneToI420:(uint8_t *)yBuffer yPixelCount:(int)yPx uvBuffer:(uint8_t *)uvBuffer uvPixelCount:(int)uvPx rotate:(KNImageRotate)r {
    
    int ysize = _width * _height;
    int uvsize  = ysize / 4;
    
    int stride = _height;
    if ((r == kKnImageRotate0) || (r == kKnImageRotate180))
        stride = _width;
    
    NV12ToI420Rotate(yBuffer, yPx, uvBuffer, uvPx,
                     _mainBuffer, stride,
                     _mainBuffer + ysize, stride / 2,
                     _mainBuffer + ysize + uvsize, stride / 2,
                     _width, _height, (enum RotationMode)r);
    
    return _mainBuffer;
}

- (uint8_t *)I420Mirror:(uint8_t *)i420Buffer w:(int)w h:(int)h {
    
    if (!_mirrorBuffer) {
        if (_mirrorBuffer) {
            free(_mirrorBuffer);
        }
        _mirrorBuffer = (uint8_t *)malloc(sizeof(uint8_t) * ((w * h * 3) >> 1));
    }

    int ysize = w * h;
    int uvsize  = ysize / 4;
    
    I420Mirror(i420Buffer, w, i420Buffer + ysize, w / 2, i420Buffer + ysize + uvsize, w / 2,
               _mirrorBuffer, w, _mirrorBuffer + ysize, w / 2, _mirrorBuffer + ysize + uvsize, w / 2, w, h);
    
    return _mirrorBuffer;
}

- (uint8_t *)NV12ToI420:(uint8_t *)yBuffer yPixelCount:(int)yPx uvBuffer:(uint8_t *)uvBuffer uvPixelCount:(int)uvPx w:(int)w h:(int)h {
    
    int ysize = w * h;
    int uvsize  = ysize / 4;

    NV12ToI420(yBuffer, yPx, uvBuffer, uvPx,
               _mainBuffer, w, _mainBuffer + ysize, w / 2, _mainBuffer + ysize + uvsize, w / 2,
               w, h);
    
    return _mainBuffer;
}
@end
