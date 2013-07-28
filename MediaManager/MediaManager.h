//
//  MediaManager.h
//  MediaManager
//
//  Created by ken on 13. 5. 31..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Global.h"

@interface MediaManager : NSObject

@property (assign, readonly) CGSize captureSize;
@property (assign, readonly) int captureFps;

+ (MediaManager *)sharedObject;

- (void)videoCaptureStart:(UIView *)preview
               resolution:(KNCaptureResolution)resolution
                      fps:(int)fps
       videoPacketizeMode:(KNVideoPacketizeMode)videoPacketizeMode
          appendRTPHeader:(BOOL)appenRTP
              encodeBlock:(void(^)(uint8_t* encData, int size))encodeBlock;

- (void)videoCaptureStop;

- (void)decodeVideo:(UIView *)videoview encData:(uint8_t *)encData size:(int)size packetizeMode:(KNVideoPacketizeMode)videoPacketizeMode;

- (void)audioCaptureStartAppendRTPHeader:(BOOL)appendRTP encodeBlock:(void(^)(uint8_t* encSpeex, int size))encodeBlock;

- (void)decodeAudio:(uint8_t *)encData size:(int)size duration:(int)millisec;

- (void)audioCaptureStop;

- (void)forceKeyFrame;

- (BOOL)getPriviewFit;
- (void)setPrivewFit:(BOOL)fit;

- (BOOL)getVideoViewFit;
- (void)setVideoViewFit:(BOOL)fit;

- (void)changeCameraPosition:(KNCameraPosition)camPos;

- (void)setOrientation:(KNVideoVideoOrientation)orientation;

@end
