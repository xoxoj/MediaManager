//
//  KNRtp.h
//  MediaManager
//
//  Created by cyh on 6/11/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "x264.h"
#import "Global.h"

@interface KNRtp : NSObject

/**
    현재 STAP-A만 지원.
 */
- (void)videoPacketizeMode:(KNVideoPacketizeMode)mode nals:(x264_nal_t *)nals nalCount:(int)nalCount packetizeBlock:(void(^)(uint8_t* packetizeData, int size))packetizeBlock;

- (void)videoDePacketizeMode:(KNVideoPacketizeMode)mode data:(uint8_t *)data size:(int)size dePacketizeBlock:(void(^)(uint8_t* packetizeData, int size))dePacketizeBlock;

- (void)appendVideoRTPHeader:(uint8_t *)data size:(int)size rtpBlock:(void(^)(uint8_t* rtpData, int size))rtpBlock;

- (void)appendAudioRTPHeader:(uint8_t *)data size:(int)size rtpBlock:(void(^)(uint8_t* rtpData, int size))rtpBlock;

@end
