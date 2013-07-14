//
//  KNX264Encoder.h
//  MediaManager
//
//  Created by cyh on 6/7/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "x264.h"

@interface KNX264Encoder : NSObject

/*
    현재 STAP-A Packetize만 구현됨.
 */
- (id)initWithEncodeSize:(CGSize)encSize
                     gop:(int)gop;

- (int)encode:(uint8_t *)i420Data
forceKeyFrame:(BOOL)forceKeyFrame
     nalBlock:(void(^)(x264_nal_t* nals, int nalCount))nalBlock;

@end
