//
//  MediaManager2.m
//  MediaManager
//
//  Created by cyh on 7/27/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import "MediaManager2.h"
#import "KNVideoManager.h"
#import "KNImageConvert.h"
#import "KNFFMpegX264Encoder.h"
#import "KNFFmpegDecoder.h"
#import "iOSGLView.h"
#import "KNX264Encoder.h"
#import "KNVP8Encoder.h"
#import "KNRtp.h"
#import "KNFFmpegDecoder.h"
#import "KNVP8Decoder.h"

static MediaManager2* gInstance = nil;

@interface MediaManager2 ()

@property (retain, nonatomic) MediaVideoParam* videoParam;
@property (retain, nonatomic) KNVideoManager* videoMgr;
@property (retain, nonatomic) KNImageConvert* imgConvert;
@property (retain, nonatomic) KNFFMpegX264Encoder* h264Encoder;
@property (retain, nonatomic) KNX264Encoder* x264Encoder;
@property (retain, nonatomic) KNVP8Encoder* vp8Encoder;
@property (retain, nonatomic) iOSGLView* glPreview;
@property (retain, nonatomic) iOSGLView* glPeerview;
@property (retain, nonatomic) KNRtp* rtp;
@property (assign, nonatomic) BOOL isRequestKeyFrame;
@property (retain, nonatomic) KNFFmpegDecoder* videoDecoderFF;
@property (retain, nonatomic) KNVP8Decoder* videoDecoderVP8;

- (void)createVideoEncoder;
- (void)createVideoDecoder;
- (void)startCapture;
- (void)encodeProcessFFMpegH264:(uint8_t *)encBuffer size:(int)size;
- (void)encodeProcessX264:(uint8_t *)encBuffer size:(int)size;
- (void)encodeProcessVP8:(uint8_t *)encBuffer size:(int)size;
- (void)paketized:(x264_nal_t *)nals nalCount:(int)nalCount;
- (void)decodeSingleNal:(uint8_t *)encBuffer size:(int)size;
- (void)decodeSTAP_A:(uint8_t *)encBuffer size:(int)size;
@end

@implementation MediaManager2

@synthesize videoParam              = _videoParam;
@synthesize videoMgr                = _videoMgr;
@synthesize imgConvert              = _imgConvert;
@synthesize h264Encoder             = _h264Encoder;
@synthesize x264Encoder             = _x264Encoder;
@synthesize vp8Encoder              = _vp8Encoder;
@synthesize glPreview               = _glPreview;
@synthesize glPeerview              = _glPeerview;
@synthesize rtp                     = _rtp;
@synthesize isRequestKeyFrame       = _isRequestKeyFrame;
@synthesize videoDecoderFF          = _videoDecoderFF;
@synthesize videoDecoderVP8         = _videoDecoderVP8;

#pragma mark - Cycle
+ (MediaManager2 *)sharedObject {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gInstance = [[MediaManager2 alloc] init];
    });

    return gInstance;
}

- (void)dealloc {
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

#pragma mark - Public
- (void)startVideoWithParam:(MediaVideoParam *)videoParam {
    
    self.videoParam = videoParam;
    
    [self createVideoEncoder];
    [self createVideoDecoder];
    [self startCapture];
}

- (void)stopVideo {
    
    [_videoMgr stopVideo];
    
    [_videoParam release];
    _videoParam = nil;
    
    [_imgConvert release];
    _imgConvert = nil;
    
    [_videoMgr release];
    _videoMgr = nil;
    
    [_h264Encoder release];
    _h264Encoder = nil;
    
    [_vp8Encoder release];
    _vp8Encoder = nil;
    
    [_videoDecoderFF release];
    _videoDecoderFF = nil;
    
    [_videoDecoderVP8 release];
    _videoDecoderVP8 = nil;
    
    [_glPeerview release];
    _glPeerview = nil;
    
    [_glPreview release];
    _glPreview = nil;
    
    [_rtp release];
    _rtp = nil;
}

#pragma mark - Private
- (void)createVideoEncoder {
    
    if (_videoParam.encVideoCodec == kKNVideoH264) {
        
        if (_videoParam.packetizeMode == kKNPacketizeMode_Single_Nal) {
            NSLog(@"Video Encoder : H264.");
            _h264Encoder = [[KNFFMpegX264Encoder alloc] initWithResolution:[_videoParam getOrientationCaptureSize]
                                                                       gop:_videoParam.captureFPS * 5];
        }

        if (_videoParam.packetizeMode == kKNPacketizeMode_STAP_A) {
            NSLog(@"Video Encoder : x264.");
            _x264Encoder = [[KNX264Encoder alloc] initWithEncodeSize:[_videoParam getOrientationCaptureSize]
                                                                 gop:_videoParam.captureFPS * 5];
        }
        
        if (_videoParam.packetizeMode == kKNPacketizeMode_FU_A) {
            NSLog(@"FU_A not supported.");
        }
        
        _rtp = [[KNRtp alloc] init];

        return;
    }
    
    
    if (_videoParam.encVideoCodec == kKNVideoVP8) {
        NSLog(@"Video Encoder : VP8.");
        _vp8Encoder = [[KNVP8Encoder alloc] initWithEncodeSize:[_videoParam getOrientationCaptureSize]
                                                           fps:_videoParam.captureFPS];
        return;
    }
}

- (void)createVideoDecoder {
    
    if ((_glPeerview == nil) &&  (_videoParam.viewPeerview)) {
        NSLog(@"PeerView Created.");
        dispatch_async(dispatch_get_main_queue(), ^{
            [_videoParam.viewPeerview retain];
            _glPeerview = [[iOSGLView alloc] initWithFrame:_videoParam.viewPeerview.bounds];
            [_videoParam.viewPeerview addSubview:_glPeerview];
            [_videoParam.viewPeerview release];
        });
    }

    if (!_videoDecoderFF && _videoParam.decVideoCodec == kKNVideoH264) {
        NSLog(@"FFMpeg Decoder Created");
        _videoDecoderFF = [[KNFFmpegDecoder alloc] initWithVideoCodecID:AV_CODEC_ID_H264
                                                           audioCodecID:kNoCodec];
    }


    if (!_videoDecoderVP8 && _videoParam.decVideoCodec == kKNVideoVP8) {
        NSLog(@"VP8 Decoder Created");
        _videoDecoderVP8 = [[KNVP8Decoder alloc] init];
    }
}


- (void)startCapture {
    
    ///프리뷰 생성.
    if (_videoParam.viewPreview) {
        _glPreview = [[iOSGLView alloc] initWithFrame:_videoParam.viewPreview.bounds];
        [_videoParam.viewPreview addSubview:_glPreview];
    }
    
    ///비디오 캡쳐 후 사용할 이미지 컨버터 생성.
    _imgConvert = [[KNImageConvert alloc] initWidthWidth:_videoParam.captureSize.width
                                                  height:_videoParam.captureSize.height];
    
    ///비디오 캡쳐 생성.
    _videoMgr = [[KNVideoManager alloc] initWidthImageConvert:_imgConvert];
    _videoMgr.videoOrientation = _videoParam.captureOrientation;
        

    ///캡쳐시작.
    _videoMgr.videoOrientation = _videoParam.captureOrientation;
    [_videoMgr startVideoWithPreview:nil
                           frameRate:_videoParam.captureFPS
                          resolution:_videoParam.captureResolution
                         captureType:kKNRawDataYUV420Planar
                           mirroring:YES
                       captureOutput:^(uint8_t *data, int len)
     {
         ///인코딩
         @synchronized(self) {
             if (_videoParam.encVideoCodec == kKNVideoH264) {
                 if (_videoParam.packetizeMode == kKNPacketizeMode_Single_Nal) {
                     [self encodeProcessFFMpegH264:data size:len];
                     return;
                 }
                 
                 if (_videoParam.packetizeMode == kKNPacketizeMode_STAP_A) {
                     [self encodeProcessX264:data size:len];
                     return;
                 }
                 return;
             }
             
             
             if (_videoParam.encVideoCodec == kKNVideoVP8) {
                 [self encodeProcessVP8:data size:len];
                 return;
             }
         }

     }previewRender:^(uint8_t *data, int w, int h) {
         if (_glPreview) {
             [_glPreview setBufferYUV2:data andWidth:w andHeight:h];
         }
     }];
}

- (void)decodeVideo:(UIView *)videoview
            encData:(uint8_t *)encData
               size:(int)size
          videoType:(KNVideoType)videoType
      packetizeMode:(KNVideoPacketizeMode)packetize {

}

- (void)encodeProcessFFMpegH264:(uint8_t *)encBuffer size:(int)size {
    
    [_h264Encoder encode:encBuffer size:size completion:^(AVPacket *pkt) {
        blockEncOutput pfnEncOut = [_videoParam getEncOuputBlock];
        if (pfnEncOut)
            pfnEncOut(pkt->data, pkt->size);
    }];
}


- (void)encodeProcessX264:(uint8_t *)encBuffer size:(int)size {
    
    [_x264Encoder encode:encBuffer
           forceKeyFrame:_isRequestKeyFrame
                nalBlock:^(x264_nal_t *nals, int nalCount, x264_picture_t *pic)
    {
        [self paketized:nals nalCount:nalCount];
    }];
}

- (void)encodeProcessVP8:(uint8_t *)encBuffer size:(int)size {
    
    [_vp8Encoder encode:encBuffer completion:^(uint8_t *encBuffer, int size) {
        blockEncOutput pfnEncOut = [_videoParam getEncOuputBlock];
        if (pfnEncOut)
            pfnEncOut(encBuffer, size);
    }];
}

- (void)paketized:(x264_nal_t *)nals nalCount:(int)nalCount {
    
    if (_videoParam.packetizeMode == kKNPacketizeMode_STAP_A) {
        [_rtp videoPacketizeMode:kKNPacketizeMode_STAP_A
                            nals:nals
                        nalCount:nalCount
                  packetizeBlock:^(uint8_t *packetizeData, int size)
         {
             if (_videoParam.appendRtpHeader) {
                 [_rtp appendVideoRTPHeader:packetizeData size:size rtpBlock:^(uint8_t *rtpData, int size) {
                     
                     blockEncOutput pfnEncOut = [_videoParam getEncOuputBlock];
                     if (pfnEncOut)
                         pfnEncOut(rtpData, size);
                 }];
             } else {
                 blockEncOutput pfnEncOut = [_videoParam getEncOuputBlock];
                 if (pfnEncOut)
                     pfnEncOut(packetizeData, size);
             }
         }];
        return;
    }
    
    if (_videoParam.packetizeMode == kKNPacketizeMode_FU_A) {
        return;
    }
}

- (void)decodeSingleNal:(uint8_t *)encBuffer size:(int)size {

    [_videoDecoderFF decodeVideo3:encBuffer size:size completion:^(uint8_t *data, int size, int w, int h) {
        [_glPeerview setBufferYUV2:data andWidth:w andHeight:h];
    }];
}


- (void)decodeSTAP_A:(uint8_t *)encBuffer size:(int)size {
    
    [_rtp videoDePacketizeMode:kKNPacketizeMode_STAP_A
                          data:encBuffer
                          size:size
              dePacketizeBlock:^(uint8_t *packetizeData, int size)
     {
         [_videoDecoderFF decodeVideo3:packetizeData size:size completion:^(uint8_t *data, int size, int w, int h) {
             [_glPeerview setBufferYUV2:data andWidth:w andHeight:h];
         }];
     }];
}




- (void)decodeVideoWithEncData:(uint8_t *)encData size:(int)size {
    
    @synchronized(self){
    
        if (_videoParam.decVideoCodec == kKNVideoH264) {
            
            if (_videoParam.packetizeMode == kKNPacketizeMode_Single_Nal) {
                [self decodeSingleNal:encData size:size];
                return;
            }
            
            if (_videoParam.packetizeMode == kKNPacketizeMode_STAP_A) {
                [self decodeSTAP_A:encData size:size];
                return;
            }
            
            if (_videoParam.packetizeMode == kKNPacketizeMode_FU_A) {
                return;
            }

            return;
        }
        
        
        if (_videoParam.decVideoCodec == kKNVideoVP8) {
            [_videoDecoderVP8 decode:encData size:size completion:^(uint8_t *decData, int decSize, int w, int h) {
                [_glPeerview setBufferYUV2:decData andWidth:w andHeight:h];
            }];
            return;
        }
    }
}
@end
