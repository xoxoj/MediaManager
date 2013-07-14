//
//  KNAudioManager.h
//  Aruts
//
//  Created by ken on 13. 5. 21..
//
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define kSamplerate8k               8000.0
#define kSamplerate16k              16000.0
#define kSamplerate22k              22050.0
#define kSamplerate32k              32000.0
#define kSamplerate44k              44100.0

@interface KNAudioManager : NSObject

@property (readonly) AudioComponentInstance audioUnit;
@property (readonly) float samplerate;

- (id)initWithSameperate:(float)samplerate;

- (void)startRecording:(void(^)(uint8_t* pcmData, int size))dataBlock;
- (void)stopRecording;

- (void)setPlayBlock:(void(^)(uint8_t* playBuffer, int size))playBlock;

@end
