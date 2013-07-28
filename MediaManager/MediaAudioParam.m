//
//  MediaAudioParam.m
//  MediaManager
//
//  Created by cyh on 7/28/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import "MediaAudioParam.h"

@interface MediaAudioParam () {
    blockEncAudioOutput blkEncAudioOutput_;
}
@end

@implementation MediaAudioParam

@synthesize encAudioCodec       = _encAudioCodec;
@synthesize decAudioCodec       = _decAudioCodec;
@synthesize samplerate          = _samplerate;
@synthesize channels            = _channels;
@synthesize appendRtpHeader     = _appendRtpHeader;
@synthesize speexQuality        = _speexQuality;
@synthesize encMiliilSec        = _encMiliilSec;

- (void)dealloc {
    
    if (blkEncAudioOutput_) {
        [blkEncAudioOutput_ release];
        blkEncAudioOutput_ = NULL;
    }
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)setEncodeBlock:(blockEncAudioOutput)encBlock {

    if (blkEncAudioOutput_) {
        [blkEncAudioOutput_ release];
        blkEncAudioOutput_ = NULL;
    }
    blkEncAudioOutput_ = [encBlock copy];
}

- (blockEncAudioOutput)getEncodeBlock {
    return blkEncAudioOutput_;
}


@end
