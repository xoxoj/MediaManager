//
//  KNX264Encoder.m
//  MediaManager
//
//  Created by cyh on 6/7/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import "KNX264Encoder.h"
#import "avcodec.h"

#define KNX264_BITRATE                  400
#define KNX264_SLICE                    1200
#define KNX264_PACKETIZEBUFFER_SIZE     1024 * 1024

@interface KNX264Encoder() {
    x264_t*                 encoder_;
    x264_picture_t          rawPicture_;
    
    uint8_t*                packetizeBuffer_;
}
@property (assign) CGSize encSize;
@property (assign) int gop;

@end

@implementation KNX264Encoder

@synthesize encSize         = _encSize;
@synthesize gop             = _gop;

- (void)dealloc {
    
    if (encoder_) {
        x264_encoder_close(encoder_);
        encoder_ = NULL;
    }
    x264_picture_clean(&rawPicture_);

    [super dealloc];
}

- (id)initWithEncodeSize:(CGSize)encSize
                     gop:(int)gop {

    self = [super init];
    if (self) {

        self.encSize = encSize;
        
        x264_param_t param;

        x264_param_default_preset(&param, "veryfast", "zerolatency");
        x264_param_apply_profile(&param, "baseline");
        

        //param.i_threads         = X264_THREADS_AUTO;
        param.i_width           = _encSize.width;
        param.i_height          = _encSize.height;
        param.i_fps_num         = _gop * 10;
        param.i_fps_den         = 1;
        param.i_slice_max_size  = KNX264_SLICE;
        param.rc.i_bitrate      = KNX264_BITRATE;
        
        encoder_ = x264_encoder_open(&param);
        x264_encoder_parameters(encoder_, &param);
        
        x264_picture_alloc(&rawPicture_, X264_CSP_I420, _encSize.width, _encSize.height);
        
        if (packetizeBuffer_ == NULL) {
            packetizeBuffer_ = (uint8_t *)malloc(sizeof(uint8_t) * KNX264_PACKETIZEBUFFER_SIZE);
            NSLog(@"@KNX264Encoder Packetization buffer size : %d byte.", KNX264_PACKETIZEBUFFER_SIZE);
        }
    }
    
    return self;
}

- (int)encode:(uint8_t *)i420Data
forceKeyFrame:(BOOL)forceKeyFrame
     nalBlock:(void(^)(x264_nal_t* nals, int nalCount))nalBlock {

    uint8_t* raw_pic_mem[3] = {rawPicture_.img.plane[0], rawPicture_.img.plane[1], rawPicture_.img.plane[2]};

    AVFrame picture;
    avpicture_fill((AVPicture *)&picture, i420Data, PIX_FMT_YUV420P, _encSize.width, _encSize.height);
    rawPicture_.img.plane[0]    = picture.data[0];
    rawPicture_.img.plane[1]    = picture.data[1];
    rawPicture_.img.plane[2]    = picture.data[2];
    rawPicture_.img.i_stride[0] = picture.linesize[0];
    rawPicture_.img.i_stride[1] = picture.linesize[1];
    rawPicture_.img.i_stride[2] = picture.linesize[2];
    
    if(forceKeyFrame    ) {
        rawPicture_.i_type = X264_TYPE_IDR;
    } else {
        rawPicture_.i_type = X264_TYPE_AUTO;
    }
    rawPicture_.i_pts = AV_NOPTS_VALUE;

    x264_nal_t* outNal;
    int outNalCount = 0;
    
    x264_picture_t pic_out;
    int encsize = x264_encoder_encode(encoder_, &outNal, &outNalCount, &rawPicture_, &pic_out);
    
    if (nalBlock) {
        nalBlock(outNal, outNalCount);
    }
    
    rawPicture_.img.plane[0] = raw_pic_mem[0];
    rawPicture_.img.plane[1] = raw_pic_mem[1];
    rawPicture_.img.plane[2] = raw_pic_mem[2];
    
    return encsize;
}

@end
