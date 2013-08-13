//
//  KNOpusDecoder.m
//  MediaManager
//
//  Created by cyh on 7/28/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import "KNOpusDecoder.h"

#define MAX_DATA_BYTES sizeof(opus_int16) * 960

@interface KNOpusDecoder () {
    OpusDecoder *dec_;
    
    int samplerate_;
    int channel_;
    
    uint32_t decBufferSize_;
    opus_int16* decBuffer_;
}
@end

@implementation KNOpusDecoder

- (void)dealloc {
    [super dealloc];
}

- (id)initWithSampleRate:(int)samplerate channels:(int)ch {
    
    self = [super init];
    if (self) {

        samplerate_ = samplerate;
        channel_    = ch;

        if ([self initCodec] == NO) {
            [self release];
            return nil;
        }

        NSLog(@"opus_decoder_create : %d, %d", samplerate_, channel_);
        
        decBufferSize_ = MAX_DATA_BYTES;
        decBuffer_ = (opus_int16 *)malloc(decBufferSize_);
    }
    return self;
}

- (BOOL)initCodec {
    
    int decError = 0;
    dec_ = opus_decoder_create((opus_int32)samplerate_, channel_, &decError);
    if (decError != OPUS_OK) {
        NSLog(@"opus_decoder_create error");
        return NO;
    }
    return YES;
}

- (void)releaseCodec {

    if (dec_) {
        opus_decoder_destroy(dec_);
        dec_ = NULL;
    }
    
    if (decBuffer_) {
        free(decBuffer_);
        decBuffer_ = NULL;
        decBufferSize_ = 0;
    }
}

- (void)decode:(uint8_t *)encData encSize:(int)encSize decBlock:(void(^)(uint8_t* decBuffer, int decSize))decBlock {

    int frameSize = opus_decode(dec_, encData, encSize, decBuffer_, MAX_DATA_BYTES, 0);
    if (frameSize <= 0) {
        NSLog(@"opus_decode error");
        return;
    }
    
    if (decBlock)
        decBlock((uint8_t *)decBuffer_, frameSize * sizeof(opus_int16));
}
@end
