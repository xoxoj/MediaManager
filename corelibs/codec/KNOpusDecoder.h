//
//  KNOpusDecoder.h
//  MediaManager
//
//  Created by cyh on 7/28/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import <Foundation/Foundation.h>
#include<opus.h>
#include<opus_defines.h>

@interface KNOpusDecoder : NSObject

- (id)initWithSampleRate:(int)samplerate channels:(int)ch;
- (void)decode:(uint8_t *)encData encSize:(int)encSize decBlock:(void(^)(uint8_t* decBuffer, int decSize))decBlock;
@end
