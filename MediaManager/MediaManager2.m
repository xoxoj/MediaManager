//
//  MediaManager2.m
//  MediaManager
//
//  Created by cyh on 7/27/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import "MediaManager2.h"
#import "KNVideoManager.h"
#import "KNAudioManager.h"
#import "KNImageConvert.h"
#import "KNFFMpegX264Encoder.h"
#import "KNFFmpegDecoder.h"
#import "iOSGLView.h"
#import "KNX264Encoder.h"
#import "KNVP8Encoder.h"
#import "KNRtp.h"
#import "KNFFmpegDecoder.h"
#import "KNVP8Decoder.h"
#import "KNAudioRingQueue.h"
#import "KNSpeexCodec.h"
#import "KNOpusEncoder.h"
#import "KNOpusDecoder.h"

static MediaManager2* gInstance = nil;

@interface MediaManager2 ()

@property (retain, nonatomic) MediaVideoParam* videoParam;
@property (retain, nonatomic) MediaAudioParam* audioParam;
@property (retain, nonatomic) KNVideoManager* videoMgr;
@property (retain, nonatomic) KNAudioManager* audioMgr;
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

@property (retain, nonatomic) KNSpeexCodec* speexCodec;
@property (retain, nonatomic) KNOpusEncoder* opusEncoder;
@property (retain, nonatomic) KNOpusDecoder* opusDecoder;
@property (retain, nonatomic) KNAudioRingQueue* captureAudioQueue;
@property (retain, nonatomic) KNAudioRingQueue* decAudioQueue;
@property (retain, nonatomic) KNAudioRingQueue* sendPacketAudioQueue;


- (void)createVideoEncoder;
- (void)createVideoDecoder;
- (void)createAudioEncoder;
- (void)createAudioDecoder;
- (void)startVideoCapture;
- (void)startAudioCapture;
- (void)encodeProcessFFMpegH264:(uint8_t *)encBuffer size:(int)size;
- (void)encodeProcessX264:(uint8_t *)encBuffer size:(int)size;
- (void)encodeProcessVP8:(uint8_t *)encBuffer size:(int)size;
- (void)encodeAudioProcess;
- (void)encodeProcessSpeex;
- (void)encodeProcessOpus;
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
@synthesize speexCodec              = _speexCodec;
@synthesize opusEncoder             = _opusEncoder;
@synthesize opusDecoder             = _opusDecoder;
@synthesize captureAudioQueue       = _captureAudioQueue;
@synthesize decAudioQueue           = _decAudioQueue;
@synthesize sendPacketAudioQueue    = _sendPacketAudioQueue;;


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
    [self startVideoCapture];
}

- (void)stopVideo {
    
    [_videoMgr stopVideo];
    [_videoMgr release];
    
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

- (void)startAudioWithParam:(MediaAudioParam *)audioParam {
    
    self.audioParam = audioParam;
    
    [self createAudioEncoder];
    [self createAudioDecoder];
    [self startAudioCapture];
}

- (void)stopAudio {
    
    [_audioMgr stopRecording];
    [_audioMgr release];
    _audioMgr = nil;
    
    [_speexCodec release];
    _speexCodec = nil;
    
    [_opusEncoder release];
    _opusEncoder = nil;
    
    [_opusDecoder release];
    _opusDecoder = nil;
    
    [_captureAudioQueue release];
    _captureAudioQueue = nil;
    
    [_decAudioQueue release];
    _decAudioQueue = nil;
    
    [_sendPacketAudioQueue release];
    _sendPacketAudioQueue = nil;

    [_audioParam release];
    _audioParam = nil;
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

- (void)decodeAudioWithEncData:(uint8_t *)encData size:(int)size {
    
    [_speexCodec decode:encData size:size completion:^(int16_t *rawBuff, int rawSize) {
        [_decAudioQueue write:(uint8_t *)rawBuff size:rawSize * sizeof(int16_t) completion:nil];
    }];
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

- (void)startVideoCapture {
    
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

- (void)createAudioEncoder {
    
    if (_audioParam.encAudioCodec == kKNAudioSpeex) {
        _speexCodec = [[KNSpeexCodec alloc] initWithBandwidth:kSpeexWide quality:8];
        return;
    }
    
    if (_audioParam.encAudioCodec == kKNAudioOpus) {
        _opusEncoder = [[KNOpusEncoder alloc] initWithSampleRate:_audioParam.samplerate channels:_audioParam.channels];
        return;
    }
}

- (void)createAudioDecoder {
    
    if (_audioParam.encAudioCodec == kKNAudioSpeex) {
        if (_speexCodec == nil)
            _speexCodec = [[KNSpeexCodec alloc] initWithBandwidth:kSpeexWide quality:8];
        return;
    }


    if (_audioParam.encAudioCodec == kKNAudioOpus) {
        _opusEncoder = [[KNOpusEncoder alloc] initWithSampleRate:_audioParam.samplerate channels:_audioParam.channels];
        return;
    }
}


- (void)startAudioCapture {

    //Audio Raw size : 320Byte / 20ms
    //Audio Speex Encoded Size : 70Byte / 20ms
    _captureAudioQueue = [[KNAudioRingQueue alloc] initWithBufferSize:320 * 50];
    _decAudioQueue = [[KNAudioRingQueue alloc] initWithBufferSize:70 * 50];
    _sendPacketAudioQueue = [[KNAudioRingQueue alloc] initWithBufferSize:70 * 4];

    
    _audioMgr = [[KNAudioManager alloc] initWithSameperate:_audioParam.samplerate];
    [_audioMgr startRecording:^(uint8_t *pcmData, int size) {
        [_captureAudioQueue write:pcmData size:size completion:nil];
        [self encodeAudioProcess];
    }];
    
    [_audioMgr setPlayBlock:^(uint8_t *playBuffer, int size) {
        @synchronized(_decAudioQueue) {
            [_decAudioQueue read:size readBlock:^(uint8_t *buffer, int readSize) {
                memcpy(playBuffer, buffer, readSize);
            }];
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
        blockEncVideoOutput pfnEncOut = [_videoParam getEncOuputBlock];
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
        blockEncVideoOutput pfnEncOut = [_videoParam getEncOuputBlock];
        if (pfnEncOut)
            pfnEncOut(encBuffer, size);
    }];
}

- (void)encodeAudioProcess {
    
    if (_audioParam.encAudioCodec == kKNAudioSpeex) {
        [self encodeProcessSpeex];
        return;
    }
    
    if (_audioParam.encAudioCodec == kKNAudioOpus) {
        [self encodeProcessOpus];
        return;
    }
}

- (void)encodeProcessSpeex {
    
    int readSize = _speexCodec.encFrameSize * sizeof(int16_t);
    [_captureAudioQueue read:readSize readBlock:^(uint8_t *buffer, int readSize) {
        [_speexCodec encode:(int16_t *)buffer size:readSize / sizeof(int16_t) completion:^(uint8_t *encBuff, int encSize) {
            blockEncAudioOutput fpnEncOut = [_audioParam getEncodeBlock];
            if (fpnEncOut) {
                fpnEncOut(encBuff, encSize);
            }
        }];
    }];
}

- (void)encodeProcessOpus {
    
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
                     
                     blockEncVideoOutput pfnEncOut = [_videoParam getEncOuputBlock];
                     if (pfnEncOut)
                         pfnEncOut(rtpData, size);
                 }];
             } else {
                 blockEncVideoOutput pfnEncOut = [_videoParam getEncOuputBlock];
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





@end
