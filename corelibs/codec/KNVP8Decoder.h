//
//  KNVP8Decoder.h
//  MediaManager
//
//  Created by cyh on 7/28/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KNVP8Decoder : NSObject

- (void)decode:(uint8_t *)encData size:(int)encSize completion:(void(^)(uint8_t* decData, int decSize, int w, int h))completion;

@end
