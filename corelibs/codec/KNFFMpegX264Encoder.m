//
//  KNFFMpegX264Codec.m
//  iMultiviewCPSLib
//
//  Created by ken on 13. 5. 22..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import "KNFFMpegX264Encoder.h"
#import "avformat.h"
#import "opt.h"
#import "imgutils.h"
#import "intreadwrite.h"

#import "scale.h"



@interface KNFFMpegX264Encoder ()

@property (assign) uint64_t frame_count;
@property (assign) AVCodecContext* encCtx;
@property (assign) AVCodec* encCodec;
@property (assign) AVFrame *rawFrame;
@property (assign) AVPacket encPacket;

@property (assign) CGSize encSize;
@property (assign) int gop;

- (BOOL)initEncoder;
@end

@implementation KNFFMpegX264Encoder

@synthesize frame_count = _frame_count;

@synthesize encCtx      = _encCtx;
@synthesize encCodec    = _encCodec;
@synthesize rawFrame    = _rawFrame;
@synthesize encPacket   = _encPacket;

@synthesize encSize     = _encSize;
@synthesize gop         = _gop;

- (void)dealloc {
    
    if (_encCtx) {
        avcodec_close(_encCtx);
        av_free(_encCtx);
        _encCtx = NULL;
    }
    
    if (_rawFrame) {
        avcodec_free_frame(&_rawFrame);
        _rawFrame = NULL;
    }

    av_free_packet(&_encPacket);
    

    [super dealloc];
}

- (id)initWithResolution:(CGSize)size
                     gop:(int)gop {

    self = [super init];
    if (self) {
        
        av_register_all();
        avcodec_register_all();
        
        _encSize = size;
        _gop = gop;

        if (_gop > 30)
            _gop = 30;
        
        if (_gop < 1)
            _gop = 1;
        
        if ([self initEncoder] == NO) {
            [self release];
            return nil;
        }
    }
    return self;
}


- (BOOL)initEncoder {

    _encCodec = avcodec_find_encoder(AV_CODEC_ID_H264);
    if (!_encCodec) {
        NSLog(@"avcodec_find_encoder error.");
        return NO;
    }

    _encCtx = avcodec_alloc_context3(_encCodec);
    if (!_encCtx) {
        NSLog(@"avcodec_alloc_context3 error.");
        return NO;
    }
    
    _encCtx->codec_id   = AV_CODEC_ID_H264;
    _encCtx->pix_fmt    = PIX_FMT_YUV420P;
    _encCtx->bit_rate   = 320000;
    _encCtx->width      = _encSize.width;
    _encCtx->height     = _encSize.height;
    _encCtx->time_base  = (AVRational){1,_gop};
    _encCtx->gop_size   = _gop * 5;
    _encCtx->profile    = FF_PROFILE_H264_BASELINE;

//    _encCtx->flags      |= CODEC_FLAG_CLOSED_GOP;
//    _encCtx->rtp_payload_size = 1200;
    
//    _encCtx->flags      |= CODEC_FLAG_GLOBAL_HEADER;


    _rawFrame = avcodec_alloc_frame();
    avcodec_get_frame_defaults(_rawFrame);
    if (!_rawFrame) {
        NSLog(@"avcodec_alloc_frame error.");
        return NO;
    }
    _rawFrame->width = _encCtx->width;
    _rawFrame->height = _encCtx->height;

    av_init_packet(&_encPacket);
    _encPacket.data = NULL;    // packet data will be allocated by the encoder
    _encPacket.size = 0;
    
    
    AVDictionary* opts = 0;
    av_dict_set(&opts, "vprofile", "baseline", 0);
    av_dict_set(&opts, "tune", "zerolatency", 0);
    av_dict_set(&opts, "preset", "ultrafast", 0);
    
    if (avcodec_open2(_encCtx, _encCodec, NULL) < 0) {
        NSLog(@"avcodec_open2 error.");
        return NO;
    }
    av_dict_free(&opts);

    NSLog(@"KNFFMpegX264Encoder extradata size : %d", _encCtx->extradata_size);
    
    return YES;
}


- (void)encode:(uint8_t*)data size:(int)size completion:(void(^)(AVPacket* pkt))completion {
    
    @synchronized(self) {
            
        av_free_packet(&_encPacket);
        av_init_packet(&_encPacket);
        
        int ret = -1;
        int got_output = 0;
        
        ret = avpicture_fill((AVPicture *)_rawFrame, data, PIX_FMT_YUV420P, _encCtx->width, _encCtx->height);
        
        _rawFrame->pts = (float)_frame_count * (1000.0/(float)(_gop)) * 90;
        
        ret = avcodec_encode_video2(_encCtx, &_encPacket, _rawFrame, &got_output);
        if (ret < 0) {
            NSLog(@"avcodec_encode_video2 error : %d", ret);
            return;
        }
        
        if (!got_output) {
            NSLog(@"avcodec_encode_video2 got_output error : %d", got_output);
            return;
        }
        
        if (_encCtx->extradata_size > 0) {

            if (got_output && completion) {
                
                if (_encPacket.flags & AVINDEX_KEYFRAME) {
                    
                    ///SPS, PPS copy.
                    AVPacket newPacket;
                    av_new_packet(&newPacket, _encCtx->extradata_size + _encPacket.size);
                    newPacket.flags = _encPacket.flags;
                    
                    memcpy(newPacket.data, _encCtx->extradata, _encCtx->extradata_size);
                    memcpy(newPacket.data + _encCtx->extradata_size, _encPacket.data, _encPacket.size);
                    
                    completion(&newPacket);
                    
                    av_free_packet(&newPacket);
                    
                } else {
                    completion(&_encPacket);
                }
            }

        } else {
            completion(&_encPacket);
        }
 
        ++_frame_count;
    }
}

@end
