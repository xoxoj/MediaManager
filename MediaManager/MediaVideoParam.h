//
//  MeidaManagerParam.h
//  MediaManager
//
//  Created by cyh on 7/27/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Global.h"

typedef void(^blockEncOutput)(uint8_t* encBuffer, int size);
//typedef void(^blockDecOutput)(uint8_t* decBuffer, int size);

@interface MediaVideoParam : NSObject

@property (retain, nonatomic) UIView* viewPreview;
@property (retain, nonatomic) UIView* viewPeerview;
@property (assign, nonatomic) KNVideoType encVideoCodec;
@property (assign, nonatomic) KNVideoType decVideoCodec;
@property (assign, nonatomic) KNCaptureResolution captureResolution;
@property (assign, nonatomic) KNVideoVideoOrientation captureOrientation;
@property (assign, nonatomic) NSInteger captureFPS;
@property (assign, nonatomic) KNVideoPacketizeMode packetizeMode;
@property (assign, nonatomic) BOOL appendRtpHeader;
@property (assign, nonatomic) CGSize captureSize;


/**
    인코딩된 데이터를 받을 블록.
 */
- (void)setEncOuputBlock:(blockEncOutput)encOut;
- (blockEncOutput)getEncOuputBlock;


///**
//    디코딩된 데이터를 받을 블록.
// */
//- (void)setDecOuputBlock:(blockDecOutput)decOut;
//- (blockDecOutput)detDecOuputBlock;


/**
    Orientation에 맞게 바뀐 캡쳐사이즈
    KNImageConvert엔 기본캡쳐사이즈, 인코더에는 바뀐챕쳐사이즈는 넣어줘여함.
 */
- (CGSize)getOrientationCaptureSize;



@end
