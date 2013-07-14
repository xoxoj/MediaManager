//
//  KNSpeexCodec.h
//  Aruts
//
//  Created by ken on 13. 5. 20..
//
//

#import <Foundation/Foundation.h>

#define SPEEX_ENCODE_DURATION       20          //20millisec

typedef enum {
    kSpeexNarrow = 0,
    kSpeexWide,
    kSpeexUltraWide
}KnSpeexBandwidth;

@interface KNSpeexCodec : NSObject

@property (readonly, assign) KnSpeexBandwidth bandwidth;
@property (readonly, assign) int quality;
@property (readonly, assign) int encFrameSize;

- (id)initWithBandwidth:(KnSpeexBandwidth)band quality:(int)q;

/*
    인, 디코딩시 넘겨주는 데이터 타입이 uint_8(byte)라면 포인터변환 및 사이즈 계산 잘할것.
 */
- (void)encode:(int16_t *)rawBuff size:(int)rawSize completion:(void(^)(uint8_t* encBuff, int encSize))completion;

- (void)decode:(uint8_t *)encBuff size:(int)encSize completion:(void(^)(int16_t* rawBuff, int rawSize))completion;

@end
