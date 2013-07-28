//
//  Global.h
//  MediaManager
//
//  Created by cyh on 6/11/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#ifndef MediaManager_Global_h
#define MediaManager_Global_h

#define kSamplerate8k               8000.0
#define kSamplerate16k              16000.0
#define kSamplerate22k              22050.0
#define kSamplerate32k              32000.0
#define kSamplerate44k              44100.0

typedef enum {
    kKNPacketizeMode_Single_Nal,
    kKNPacketizeMode_FU_A, //<<---미구현
    kKNPacketizeMode_STAP_A
    
}KNVideoPacketizeMode;

typedef enum {
    kKNVideoOrientationPortrait,
    kKNVideoOrientationLandscape
}KNVideoVideoOrientation;


typedef enum {
    kKNGravityResizeToFit,
    kKNGravityAspectFill,
    kKNGravityAspectFit
}KNPreviewGravity;

typedef enum {
    kKNCameraFront,
    kKNCameraBack,
    kKNCameraOff,
}KNCameraPosition;


typedef enum {
    kKNCaptureHigh,
    kKNCaptureMedium,
    kKNCaptureLow,
    kKNCapture288,
    kKNCapture480,
    kKNCapture720,
    kKNCapture1080
}KNCaptureResolution;

typedef enum {
    kKNRawDataRGB32,
    kKNRawDataYUV420Planar
}KNRawDataType;


typedef enum {
    kKNVideoH264,
    kKNVideoVP8
}KNVideoType;

typedef enum {
    kKNAudioSpeex,
    kKNAudioOpus
}KNAudioType;


#endif
