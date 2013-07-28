//
//  KNVP8Encoder.h
//  MediaManager
//
//  Created by cyh on 7/27/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <vpx_codec.h>
#import <vpx_encoder.h>
#import <vpx_decoder.h>
#import <vp8.h>
#import <vp8cx.h>
#import <vp8dx.h>

@interface KNVP8Encoder : NSObject

- (id)initWithEncodeSize:(CGSize)encSize
                     fps:(int)fps;

- (void)encode:(uint8_t *)buffer completion:(void(^)(uint8_t* encBuffer, int size))completion;

@end
