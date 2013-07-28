//
//  MediaManager2.h
//  MediaManager
//
//  Created by cyh on 7/27/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Global.h"
#import "MediaVideoParam.h"

@interface MediaManager2 : NSObject

+ (MediaManager2 *)sharedObject;

- (void)startVideoWithParam:(MediaVideoParam *)videoParam;
- (void)stopVideo;

//패킷타이즈 자동 체크하도록 수정할것.
- (void)decodeVideo:(UIView *)videoview
            encData:(uint8_t *)encData
               size:(int)size
          videoType:(KNVideoType)videoType
      packetizeMode:(KNVideoPacketizeMode)packetize;

- (void)decodeVideo2:(UIView *)peerView encData:(uint8_t *)encData size:(int)size;

@end
