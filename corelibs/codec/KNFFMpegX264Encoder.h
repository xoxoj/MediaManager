//
//  KNFFMpegX264Codec.h
//  iMultiviewCPSLib
//
//  Created by ken on 13. 5. 22..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "avcodec.h"

@interface KNFFMpegX264Encoder : NSObject

@property (assign, readonly) AVCodecContext* encCtx;
@property (assign, readonly) AVCodec* encCodec;
@property (assign, readonly) CGSize encSize;
@property (assign, readonly) int quality;
@property (assign, readonly) int gop;

- (id)initWithResolution:(CGSize)size
                     gop:(int)gop;

- (void)encode:(uint8_t*)data size:(int)size completion:(void(^)(AVPacket* pkt))completion;

@end
