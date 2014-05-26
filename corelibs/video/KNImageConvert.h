//
//  KNImageConvert.h
//  iMultiviewCPSLib
//
//  Created by ken on 13. 5. 30..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    
    kKnImageRotate0 = 0,
    kKnImageRotate90 = 90,
    kKnImageRotate180 = 180,
    kKnImageRotate270 = 270
    
}KNImageRotate;

@interface KNImageConvert : NSObject

@property (assign) NSInteger width;
@property (assign) NSInteger height;
@property (assign) NSInteger bufferSize;

- (id)initWidthWidth:(int)w height:(int)h;

- (uint8_t *)rgb32ToI420Rotate:(uint8_t *)rgbBuffer size:(int)size rotate:(KNImageRotate)r;

- (uint8_t *)I420Scale:(uint8_t*)yuvBuffer srcW:(int)srcW srcH:(int)srcH dstW:(int)dstW dstH:(int)dstH roatated:(BOOL)isRorated;

- (uint8_t *)YUV420PlaneToI420:(uint8_t *)yBuffer yPixelCount:(int)yPx uvBuffer:(uint8_t *)uvBuffer uvPixelCount:(int)uvPx rotate:(KNImageRotate)r bytePerRow:(int)bytePerRaw;

- (uint8_t *)I420Mirror:(uint8_t *)i420Buffer w:(int)w h:(int)h;

- (uint8_t *)NV12ToI420:(uint8_t *)yBuffer yPixelCount:(int)yPx uvBuffer:(uint8_t *)uvBuffer uvPixelCount:(int)uvPx w:(int)w h:(int)h;

@end
