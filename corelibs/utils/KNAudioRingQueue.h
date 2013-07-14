//
//  KNAudioRingQueue.h
//  Aruts
//
//  Created by ken on 13. 5. 21..
//
//

#import <Foundation/Foundation.h>

#define kMegaByte  1024 * 1024

@interface KNAudioRingQueue : NSObject

@property (readonly, assign) int bufferSize;
@property (readonly, assign) int written;
@property (readonly, assign) int seek;

- (id)initWithBufferSize:(int)size;

- (void)write:(uint8_t *)pSrcBuffer size:(int)size completion:(void(^)(void))completion;

- (void)read:(int)size readBlock:(void(^)(uint8_t* buffer, int readSize))readBlock;

@end
