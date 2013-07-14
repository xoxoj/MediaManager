//
//  KNFFmpegDecoder.h
//  GLKDrawTest
//
//  Created by Choi Yeong Hyeon on 12. 11. 25..
//  Copyright (c) 2012년 Choi Yeong Hyeon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "avcodec.h"

#define kKNFFDecKeyWidth        @"width"
#define kKNFFDecKeyHeigth       @"height"
#define kKNFFDecKeyLuma         @"luma"
#define kKNFFDecKeyChromaB      @"chromaB"
#define kKNFFDecKeyChromaR      @"chromaR"

#define kNoCodec                AV_CODEC_ID_NONE

@interface KNFFmpegDecoder : NSObject

- (id)initWithVideoCodecID:(enum AVCodecID)vcodecid
              audioCodecID:(enum AVCodecID)acodecid;

/*
    frameData key
    width
    heigth
    ydata
    udata
    vdata
 */
- (void)decodeVideo:(AVPacket *)packet
         completion:(void(^)(NSDictionary* frameData))completion;

- (void)decodeVideo2:(AVPacket *)packet
         completion:(void(^)(uint8_t* data, int size, int w, int h))completion;

- (void)decodeVideo3:(uint8_t *)encData size:(int)size
          completion:(void(^)(uint8_t* data, int size, int w, int h))completion;


- (void)decodeAudio:(AVPacket *)packet
         completion:(void(^)(NSDictionary* frameData))completion;

- (void)endDecode;


@end
