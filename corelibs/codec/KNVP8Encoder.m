//
//  KNVP8Encoder.m
//  MediaManager
//
//  Created by cyh on 7/27/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import "KNVP8Encoder.h"

//#define interface (vpx_codec_vp8_cx())

@interface KNVP8Encoder () {
    vpx_codec_ctx_t             ctx_;
    vpx_codec_iface_t*          interface_;
    vpx_codec_enc_cfg_t         config_;
    vpx_image_t                 rawPicture_;
    const vpx_codec_cx_pkt_t*   encodePkt_;
    
    uint8_t*                    yuvBuffer_;
    uint32_t                    yuvBufferSize_;
}
@property (assign, nonatomic) CGSize encSize;
@property (assign, nonatomic) int encFps;
@property (assign, nonatomic) int frameCount;

- (BOOL)initCodec;
- (void)releaseCodec;

@end

@implementation KNVP8Encoder

@synthesize encSize         = _encSize;
@synthesize encFps          = _encFps;
@synthesize frameCount      = _frameCount;

- (void)dealloc {
    
    [self releaseCodec];
    [super dealloc];
}

- (id)initWithEncodeSize:(CGSize)encSize
                     fps:(int)fps {

    self = [super init];
    if (self) {
        _encSize = encSize;
        _encFps = fps;
        
        if ([self initCodec] == NO) {
            [self release];
            return nil;
        }
        
        NSLog(@"VP8 Encode Size : %dx%d", (int)encSize.width, (int)encSize.height);
//        yuvBufferSize_ = ((int)_encSize.width * (int)_encSize.height) >> 3;
//        yuvBuffer_ = (uint8_t *)malloc(sizeof(uint8_t *) * yuvBufferSize_);
    }
    return self;
}


- (void)encode:(uint8_t *)buffer completion:(void(^)(uint8_t* encBuffer, int size))completion {
    
    int ysize = _encSize.width * _encSize.height;
    int uvsize  = ysize / 4;
    
    rawPicture_.planes[VPX_PLANE_Y] = buffer;
	rawPicture_.planes[VPX_PLANE_U] = buffer + ysize;
    rawPicture_.planes[VPX_PLANE_V] = buffer + (ysize + uvsize);
    
    vpx_codec_err_t err = vpx_codec_encode(&ctx_, &rawPicture_, _frameCount++, 1, 0, VPX_DL_GOOD_QUALITY);
    if (err) {
        [self codecDie:@"Failed to encode frame"];
        return;
    }
    
    vpx_codec_iter_t iter = NULL;
	encodePkt_ = vpx_codec_get_cx_data(&ctx_, &iter);
    
    if(encodePkt_->kind == VPX_CODEC_CX_FRAME_PKT) {
        if (completion) {
            completion((uint8_t *)encodePkt_->data.frame.buf, (int)encodePkt_->data.frame.sz);
        }
    }
    else if(encodePkt_->kind == VPX_CODEC_STATS_PKT) {
        NSString* msg = [NSString stringWithFormat:@"encodeFrame stat_pkt %d", (int)encodePkt_->data.frame.sz];
        [self codecDie:msg];
    }
    else {
        [self codecDie:@"encode default"];
    }

}

- (void)codecDie:(NSString *)msg {
    const char *detail = vpx_codec_error_detail(&ctx_);
     NSLog(@"%@: %s, %s\n", msg, detail, vpx_codec_error(&ctx_));
}

- (BOOL)initCodec {
    
    vpx_img_alloc(&rawPicture_,
    			  VPX_IMG_FMT_I420,
                  (unsigned int)_encSize.width,
                  (unsigned int)_encSize.height,
                  32);

    
    interface_ = vpx_codec_vp8_cx();
    
    int res = vpx_codec_enc_config_default(interface_, &config_, 0);
    if(res) {
        NSLog(@"Failed to get config: %s", vpx_codec_err_to_string(res));
        return NO;
    }
    config_.rc_target_bitrate = _encSize.width * _encSize.height * config_.rc_target_bitrate;
//    config_.rc_target_bitrate = _encFps;
    config_.g_w = _encSize.width;
    config_.g_h = _encSize.height;
    config_.g_pass = VPX_RC_ONE_PASS;

    int ret = vpx_codec_enc_init(&ctx_, vpx_codec_vp8_cx(), &config_, 0);
    if (ret) {
        [self codecDie:@"VPX INIT"];
        return NO;
    }    
    return YES;
}

- (void)releaseCodec {
    vpx_img_free(&rawPicture_);
    if(vpx_codec_destroy(&ctx_)) {
        [self codecDie:@"Failed to destroy codec"];
    }
}

@end
