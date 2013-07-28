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

/**
    패킷타이즈 설정은 인/디코딩 같이감.
 */
- (void)startVideoWithParam:(MediaVideoParam *)videoParam;
- (void)stopVideo;
- (void)decodeVideoWithEncData:(uint8_t *)encData size:(int)size;

@end
