//
//  KNOpusEncoder.m
//  MediaManager
//
//  Created by cyh on 7/28/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import "KNOpusEncoder.h"

#define MAX_DATA_BYTES sizeof(opus_int16) * 960

@interface KNOpusEncoder () {
    OpusEncoder *enc_;
    
    int samplerate_;
    int channel_;
    
    uint32_t encBufferSize_;
    uint8_t* encBuffer_;
}
@end

@implementation KNOpusEncoder

@synthesize frameSize = _frameSize;

- (void)dealloc {
    
    [self release];
    [super dealloc];
}

- (id)initWithSampleRate:(int)samplerate channels:(int)ch {

    self = [super init];
    if (self) {

        samplerate_     = samplerate;
        channel_        = ch;
        _frameSize      = 960;

        NSLog(@"opus_encoder_create : %d, %d", samplerate_, channel_);
        
        if ([self initCodec] == NO) {
            [self release];
            return nil;
        }
        
        encBufferSize_ = MAX_DATA_BYTES;
        encBuffer_ = (uint8_t *)malloc(encBufferSize_);
    }
    return self;
}

- (BOOL)initCodec {
    
    int encError = 0;
    enc_ = opus_encoder_create((opus_int32)samplerate_, channel_, OPUS_APPLICATION_VOIP, &encError);
    if (encError != OPUS_OK) {
        NSLog(@"opus_encoder_create error");
        return NO;
    }
    
    opus_encoder_ctl(enc_, OPUS_SET_COMPLEXITY(0));
    
    return YES;
}

- (void)releaseCodec {

    if (enc_) {
        opus_encoder_destroy(enc_);
        enc_ = NULL;
    }
    
    if (encBuffer_) {
        free(encBuffer_);
        encBuffer_ = NULL;
        encBufferSize_ = 0;
    }
}


- (void)encode:(const opus_int16 *)pcm encBlock:(void(^)(uint8_t* encBuffer, int size))encBlock {

    int encSize = opus_encode(enc_, pcm, _frameSize, encBuffer_, MAX_DATA_BYTES);
    if (encBlock) {
        encBlock(encBuffer_, encSize);
    }
}

@end
