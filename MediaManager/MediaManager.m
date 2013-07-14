//
//  MediaManager.m
//  MediaManager
//
//  Created by ken on 13. 5. 31..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import "MediaManager.h"

#import "KNVideoManager.h"
#import "KNImageConvert.h"
#import "KNFFMpegX264Encoder.h"
#import "KNFFmpegDecoder.h"
#import "iOSGLView.h"

#import "KNAudioManager.h"
#import "KNSpeexCodec.h"
#import "KNAudioRingQueue.h"

#import "avformat.h"
#import "KNX264Encoder.h"

#import "KNRtp.h"

static MediaManager* gInstance = nil;

@interface MediaManager () {
    uint8_t* audioDecodeBuffer_;
    int audioDecodeBufferSize_;
    
    BOOL forceKeyFrame_;
}

@property (assign) CGSize captureSize;
@property (assign) int captureFps;

@property (retain, nonatomic) KNVideoManager* videoMgr;
@property (retain, nonatomic) KNImageConvert* imgConvert;
@property (retain, nonatomic) KNFFMpegX264Encoder* h264Encoder;
@property (retain, nonatomic) KNX264Encoder* x264Encoder;

@property (retain, nonatomic) KNFFmpegDecoder* videoDecoder;
@property (retain, nonatomic) iOSGLView* glPreview;
@property (retain, nonatomic) iOSGLView* glvideoview;

@property (retain, nonatomic) KNAudioManager* audioMgr;
@property (retain, nonatomic) KNSpeexCodec* speex;
@property (retain, nonatomic) KNAudioRingQueue* encAudioQueue;
@property (retain, nonatomic) KNAudioRingQueue* decAudioQueue;
@property (retain, nonatomic) KNAudioRingQueue* sendPacketAudioQueue;

@property (retain, nonatomic) KNRtp* rtp;

@property (retain, nonatomic) NSObject* encSyncObject;
@property (assign) KNVideoPacketizeMode packetizeMode;
@property (assign) BOOL appenVideoRTPHeader;
@property (assign) BOOL appenAudioRTPHeader;

@end

@implementation MediaManager

@synthesize captureSize         = _captureSize;
@synthesize captureFps          = _captureFps;

@synthesize videoMgr            = _videoMgr;
@synthesize imgConvert          = _imgConvert;
@synthesize h264Encoder         = _h264Encoder;
@synthesize x264Encoder         = _x264Encoder;

@synthesize glPreview           = _glPreview;
@synthesize glvideoview         = _glvideoview;

@synthesize audioMgr            = _audioMgr;
@synthesize speex               = _speex;
@synthesize encAudioQueue       = _encAudioQueue;
@synthesize decAudioQueue       = _decAudioQueue;
@synthesize sendPacketAudioQueue= _sendPacketAudioQueue;
@synthesize rtp                 = _rtp;
@synthesize packetizeMode       = _packetizeMode;
@synthesize appenVideoRTPHeader = _appenVideoRTPHeader;
@synthesize appenAudioRTPHeader = _appenAudioRTPHeader;


+ (MediaManager *)sharedObject {
   
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (gInstance == nil)
            gInstance = [[MediaManager alloc] init];
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

- (BOOL)initVideo {
    return YES;
}

- (void)calCaptureSize:(KNCaptureResolution)resolution {
    
    // 전면카메라 기준 전면가메라는 640x480까지만 지원
    
    _captureSize = CGSizeMake(0, 0);
    
    if (resolution == kKNCaptureLow) {
        _captureSize = CGSizeMake(192, 144);
    } else if (resolution == kKNCaptureMedium) {
        _captureSize = CGSizeMake(480, 360);
    } else if (resolution == kKNCaptureHigh) {
        _captureSize = CGSizeMake(640, 480);
    } else if (resolution == kKNCapture288) {
        _captureSize = CGSizeMake(352, 288);
    } else if (resolution == kKNCapture480) {
        _captureSize = CGSizeMake(640, 480);
    } else if (resolution == kKNCapture720) {
        _captureSize = CGSizeMake(1280, 720);
    } else if (resolution == kKNCapture1080) {
        _captureSize = CGSizeMake(1920, 1080);
    } else {
        _captureSize = CGSizeMake(192, 144);
    }
    
//    if (_captureSize.height > 480) {
//        NSLog(@"%s Front Camera Does not support over 640x480. Change capture resolution 192x144.", __func__);
//        _captureSize = CGSizeMake(192, 144);
//    }
}

- (void)videoCaptureStart:(UIView *)preview
               resolution:(KNCaptureResolution)resolution
                      fps:(int)fps
       videoPacketizeMode:(KNVideoPacketizeMode)videoPacketizeMode
          appendRTPHeader:(BOOL)appenRTP
              encodeBlock:(void(^)(uint8_t* encData, int size))encodeBlock {

    _packetizeMode = videoPacketizeMode;
    _appenVideoRTPHeader = appenRTP;
    
    _captureFps = fps;
    [self calCaptureSize:resolution];
    NSLog(@"CAPTURE SIZE : %dx%d, FPS : %d", (int)_captureSize.width, (int)_captureSize.height, _captureFps);
    
    _imgConvert = [[KNImageConvert alloc] initWidthWidth:_captureSize.width height:_captureSize.height];
    if (_imgConvert == nil) {
        NSLog(@"%s KNImageConvert nil.", __func__);
    }
    
    _videoMgr = [[KNVideoManager alloc] initWidthImageConvert:_imgConvert];
    if (_videoMgr == nil) {
        NSLog(@"%s KNVideoManager nil.", __func__);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _glPreview = [[iOSGLView alloc] initWithFrame:preview.bounds];
        [preview addSubview:_glPreview];
        
        BOOL iPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
        if (!iPad) {
            float tmp = _captureSize.width;
            _captureSize.width = _captureSize.height;
            _captureSize.height = tmp;
        }
        
    
        if (_packetizeMode == kKNPacketizeMode_Single_Nal) {
            _h264Encoder = [[KNFFMpegX264Encoder alloc] initWithResolution:CGSizeMake(_captureSize.width, _captureSize.height)
                                                                       gop:_captureFps];
            self.encSyncObject = _h264Encoder;
            NSLog(@"H264 Encoder Single-Nal Mode.");
        } else  {
            _x264Encoder = [[KNX264Encoder alloc] initWithEncodeSize:_captureSize
                                                                 gop:fps * 5];
            self.encSyncObject = _x264Encoder;
            NSLog(@"H264 Encoder STAP-A Mode.");
        }
        
        _rtp = [[KNRtp alloc] init];
        
        NSLog(@"Encoding : %dx%d", (int)_captureSize.width, (int)_captureSize.height);
        
        
        [_videoMgr startVideoWithPreview:nil
                               frameRate:fps
                              resolution:resolution
                             captureType:kKNRawDataYUV420Planar
                               mirroring:YES
                           captureOutput:^(uint8_t *data, int len)
         {
             @synchronized(self.encSyncObject) {
                 
                 if (_packetizeMode == kKNPacketizeMode_Single_Nal) {
                     
                     [_h264Encoder encode:data size:len completion:^(AVPacket *pkt) {
                         if (encodeBlock) {
                             if (_appenVideoRTPHeader) {
                                 [_rtp appendVideoRTPHeader:pkt->data size:pkt->size rtpBlock:^(uint8_t *rtpData, int size) {
                                     encodeBlock(rtpData, size);
                                 }];
                             } else {
                                encodeBlock(pkt->data, pkt->size);
                             }
                         }
                     }];

                 } else {

                     [_x264Encoder encode:data forceKeyFrame:forceKeyFrame_ nalBlock:^(x264_nal_t *nals, int nalCount) {
                         
                         ///STAP-A 패킷타이징.
                         [_rtp videoPacketizeMode:kKNPacketizeMode_STAP_A
                                             nals:nals
                                         nalCount:nalCount
                                   packetizeBlock:^(uint8_t *packetizeData, int size)
                         {
                             if (_appenVideoRTPHeader) {
                                 [_rtp appendVideoRTPHeader:packetizeData size:size rtpBlock:^(uint8_t *rtpData, int size) {
                                     if (encodeBlock)
                                         encodeBlock(rtpData, size);
                                 }];
                             } else {
                                 if (encodeBlock)
                                     encodeBlock(packetizeData, size);
                             }
                         }];
                     }];
                 }
             }
             
         } previewRender:^(uint8_t *data, int w, int h) {
             [_glPreview setBufferYUV2:data andWidth:w andHeight:h];
         }];
    });
}

- (void)videoCaptureStop {
    
    [_videoMgr stopVideo];
    
    [_imgConvert release];
    _imgConvert = nil;
    
    [_videoMgr release];
    _videoMgr = nil;
    
    [_h264Encoder release];
    _h264Encoder = nil;
    
    [_videoDecoder release];
    _videoDecoder = nil;
    
    [_glvideoview release];
    _glvideoview = nil;
    
    [_glPreview release];
    _glPreview = nil;
    
    [_rtp release];
    _rtp = nil;
}

- (void)decodeVideo:(UIView *)videoview encData:(uint8_t *)encData size:(int)size {

    if (_videoDecoder == nil) {
        _videoDecoder = [[KNFFmpegDecoder alloc] initWithVideoCodecID:AV_CODEC_ID_H264
                                                         audioCodecID:kNoCodec];
    }
    
    if (_glvideoview == nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [videoview retain];
            _glvideoview = [[iOSGLView alloc] initWithFrame:videoview.bounds];
            [videoview addSubview:_glvideoview];
            [videoview release];
        });
    }
    
    [_rtp videoDePacketizeMode:kKNPacketizeMode_STAP_A
                          data:encData
                          size:size
              dePacketizeBlock:^(uint8_t *packetizeData, int size)
    {
        [_videoDecoder decodeVideo3:packetizeData size:size completion:^(uint8_t *data, int size, int w, int h) {
            [_glvideoview setBufferYUV2:data andWidth:w andHeight:h];
        }];
    }];
}

- (void)audioCaptureStartAppendRTPHeader:(BOOL)appendRTP encodeBlock:(void(^)(uint8_t* encSpeex, int size))encodeBlock {
    
    _appenAudioRTPHeader = appendRTP;

    _audioMgr = [[KNAudioManager alloc] initWithSameperate:kSamplerate16k];
    if (_audioMgr == nil) {
        NSLog(@"KNAudioManager nil.");
        return;
    }
    
    
    _speex = [[KNSpeexCodec alloc] initWithBandwidth:kSpeexWide quality:8];
    if (_speex == nil) {
        NSLog(@"KNSpeexCodec nil.");
        return;
    }
    
    
    //Audio Raw size : 320Byte / 20ms
    //Audio Speex Encoded Size : 70Byte / 20ms
    _encAudioQueue = [[KNAudioRingQueue alloc] initWithBufferSize:320 * 50];
    _decAudioQueue = [[KNAudioRingQueue alloc] initWithBufferSize:70 * 50];
    _sendPacketAudioQueue = [[KNAudioRingQueue alloc] initWithBufferSize:70 * 4];
    
    /**
        멀티뷰는 스픽스 인코딩 데이터를 40ms 단위로 통신하므로 캡쳐될때마다 큐에 넣고 20ms씩 인코딩하여
        40ms만큼 데이터가 모이면 전송한다.
     */
    [_audioMgr startRecording:^(uint8_t *pcmData, int size) {
        
        ///인코딩큐에 삽입. (캡쳐되는 사이즈와 스픽스 인코드 사이즈가 달라 일단 버퍼에 넣는다.
        [_encAudioQueue write:pcmData size:size completion:^{
            
            ///인코드큐에서 스픽스 인코딩 가능한 사이즈많큼 읽어온다.
            int readSize = _speex.encFrameSize * sizeof(int16_t);
            [_encAudioQueue read:readSize readBlock:^(uint8_t *buffer, int readSize) {
                
                ///스픽스 인코드
                [_speex encode:(int16_t *)buffer size:readSize / sizeof(int16_t) completion:^(uint8_t *encBuff, int encSize) {
                    
                    ///멀티뷰가 40ms씩 패킷을 주고 받기때문에 일단 인코딩 패킷큐에 인코드 데이터를 넣는다. (스픽스인코딩 길이는 20ms이다.)
                    [_sendPacketAudioQueue write:encBuff size:encSize completion:^{
                        
                        ///만약 인코딩 데이터가 40ms 만큼 있다면 읽어서 보낸다.
                        if (_sendPacketAudioQueue.written >= (encSize * 2)){
                            [_sendPacketAudioQueue read:encSize * 2 readBlock:^(uint8_t *buffer, int readSize) {
                                
                                if (_appenAudioRTPHeader) {
                                    [_rtp appendAudioRTPHeader:buffer size:readSize rtpBlock:^(uint8_t *rtpData, int size) {
                                        if (encodeBlock)
                                            encodeBlock(rtpData, size);
                                    }];
                                } else {
                                    if (encodeBlock)
                                        encodeBlock(buffer, readSize);
                                }
                            }];
                        }
                    }];
                }];
            }];
        }];
    }];
    
    
    [_audioMgr setPlayBlock:^(uint8_t *playBuffer, int size) {
        @synchronized(_decAudioQueue) {
            [_decAudioQueue read:size readBlock:^(uint8_t *buffer, int readSize) {
                memcpy(playBuffer, buffer, readSize);
            }];
        }
    }];
}

- (void)decodeAudio:(uint8_t *)encData size:(int)size duration:(int)millisec {
    
    @synchronized(_decAudioQueue) {
    
        if (audioDecodeBuffer_ == NULL) {
            audioDecodeBufferSize_ = size;
            audioDecodeBuffer_ = (uint8_t *)malloc(sizeof(uint8_t) * audioDecodeBufferSize_);
            
        }
        
        if (audioDecodeBufferSize_ < size) {
            free(audioDecodeBuffer_);
            
            audioDecodeBufferSize_ = size;
            audioDecodeBuffer_ = (uint8_t *)malloc(sizeof(uint8_t) * audioDecodeBufferSize_);
        }
        
        int copySize = size;
        memcpy(audioDecodeBuffer_, encData, copySize);
    
        int written = 0;
        int loop = millisec / SPEEX_ENCODE_DURATION;
        for (int i = 0; i < loop; i++) {
            [_speex decode:audioDecodeBuffer_ + written size:size / loop completion:^(int16_t *rawBuff, int rawSize) {
                [_decAudioQueue write:(uint8_t *)rawBuff size:rawSize * sizeof(int16_t) completion:nil];
            }];
            written += size/loop;
        }
    }
}

- (void)audioCaptureStop {

    [_audioMgr stopRecording];

    
    [_audioMgr release];
    _audioMgr = nil;

    [_speex release];
    _speex = nil;
    
    [_encAudioQueue release];
    _encAudioQueue = nil;

    [_decAudioQueue release];
    _decAudioQueue = nil;
    
    [_rtp release];
    _rtp = nil;

    [_sendPacketAudioQueue release];
    _sendPacketAudioQueue = nil;
    
    
    if (audioDecodeBuffer_) {
        free(audioDecodeBuffer_);
        audioDecodeBuffer_ = NULL;
        audioDecodeBufferSize_ = 0;
    }
}

- (void)forceKeyFrame {
    
    if (forceKeyFrame_ == NO)
        forceKeyFrame_ = YES;
}

- (BOOL)getPriviewFit {
    
    if (_glPreview.contentMode == UIViewContentModeScaleAspectFit)
        return YES;
    
    return NO;
}

- (void)setPrivewFit:(BOOL)fit {
    if (fit) {
        _glPreview.contentMode = UIViewContentModeScaleAspectFit;
    } else {
        _glPreview.contentMode = UIViewContentModeScaleAspectFill;
    }
}

- (BOOL)getVideoViewFit {
    if (_glvideoview.contentMode == UIViewContentModeScaleAspectFit)
        return YES;
    
    return NO;
}

- (void)setVideoViewFit:(BOOL)fit {
    if (fit) {
        _glvideoview.contentMode = UIViewContentModeScaleAspectFit;
    } else {
        _glvideoview.contentMode = UIViewContentModeScaleAspectFill;
    }
}

- (void)changeCameraPosition:(KNCameraPosition)camPos {
    [self.videoMgr changeCameraPosition:camPos];
}

@end
