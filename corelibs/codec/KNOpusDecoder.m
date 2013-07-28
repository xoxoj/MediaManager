//
//  KNOpusDecoder.m
//  MediaManager
//
//  Created by cyh on 7/28/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import "KNOpusDecoder.h"

#define MAX_DATA_BYTES 1000

@interface KNOpusDecoder () {
    OpusDecoder *dec_;
    
    int samplerate_;
    int channel_;
    
    uint32_t decBufferSize_;
    uint16_t* decBuffer_;
    
    
}
@end

@implementation KNOpusDecoder

- (void)dealloc {
    [super dealloc];
}

- (id)initWithSampleRate:(int)samplerate channels:(int)ch {
    
    self = [super init];
    if (self) {
        
        if ([self initCodec] == NO) {
            [self release];
            return nil;
        }
        samplerate_ = samplerate;
        channel_ = ch;
        
        decBufferSize_ = sizeof(uint16_t) * 1500;
        decBuffer_ = (uint16_t *)malloc(decBufferSize_);
    }
    return self;
}

- (BOOL)initCodec {
    
    int decError = 0;
    dec_ = opus_decoder_create(samplerate_, channel_, &decError);
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

- (void)encode:(uint8_t *)encData size:(int)size decBlock:(void(^)(uint8_t* decBuffer, int size))decBlock {

    int frameSize = opus_decode(dec_, encData, size, (opus_int16 *)decBuffer_, MAX_DATA_BYTES, 0);
    if (frameSize <= 0) {
        NSLog(@"opus_decode error");
        return;
    }
    
    if (decBlock)
        decBlock((uint8_t *)decBuffer_, frameSize * 2);
}
@end
