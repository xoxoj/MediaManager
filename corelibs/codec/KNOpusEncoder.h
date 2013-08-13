//
//  KNOpusEncoder.h
//  MediaManager
//
//  Created by cyh on 7/28/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import <Foundation/Foundation.h>
#include<opus.h>
#include<opus_defines.h>

@interface KNOpusEncoder : NSObject

@property (assign) int frameSize;

- (id)initWithSampleRate:(int)samplerate channels:(int)ch;
- (void)encode:(const opus_int16 *)pcm encBlock:(void(^)(uint8_t* encBuffer, int size))encBlock;

@end
