//
//  KNAudioManager.h
//  Aruts
//
//  Created by ken on 13. 5. 21..
//
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "Global.h"

@interface KNAudioManager : NSObject

@property (readonly) AudioComponentInstance audioUnit;
@property (readonly) float samplerate;

- (id)initWithSamplerate:(float)samplerate;

- (void)startRecording:(void(^)(uint8_t* pcmData, int size))dataBlock;
- (void)stopRecording;

- (void)setPlayBlock:(void(^)(uint8_t* playBuffer, int size))playBlock;

@end
