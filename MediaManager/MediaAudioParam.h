//
//  MediaAudioParam.h
//  MediaManager
//
//  Created by cyh on 7/28/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Global.h"

typedef void(^blockEncAudioOutput)(uint8_t* encBuffer, int size);

@interface MediaAudioParam : NSObject

@property (assign, nonatomic) KNAudioType encAudioCodec;
@property (assign, nonatomic) KNAudioType decAudioCodec;
@property (assign, nonatomic) float samplerate;
@property (assign, nonatomic) int channels;
@property (assign, nonatomic) BOOL appendRtpHeader;
@property (assign, nonatomic) int speexQuality;
@property (assign, nonatomic) int encMiliilSec;

- (void)setEncodeBlock:(blockEncAudioOutput)encBlock;
- (blockEncAudioOutput)getEncodeBlock;

@end
