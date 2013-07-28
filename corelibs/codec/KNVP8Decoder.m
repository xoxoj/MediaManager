//
//  KNVP8Decoder.m
//  MediaManager
//
//  Created by cyh on 7/28/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

//http://www.webmproject.org/docs/vp8-sdk/example__simple__decoder.html

#import "KNVP8Decoder.h"
#import <vpx_codec.h>
#import <vpx_encoder.h>
#import <vpx_decoder.h>
#import <vp8.h>
#import <vp8cx.h>
#import <vp8dx.h>

@interface KNVP8Decoder () {
    vpx_codec_ctx_t         ctx_;
    vpx_codec_iface_t*      interface_;
    
    uint8_t*                decodeBuffer_;
    uint32_t                decodeBufferSize_;
}
@end

@implementation KNVP8Decoder

- (void)dealloc {
    
    [self releaseCodec];
    free(decodeBuffer_);
    decodeBuffer_ = NULL;
    decodeBufferSize_ = 0;
    
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self) {
        
        if ([self initCodec] == NO) {
            [self release];
            return nil;
        }
        
        decodeBufferSize_ = (1280 * 720);
        decodeBuffer_ = (uint8_t *)malloc(sizeof(uint8_t) * decodeBufferSize_);
    }
    return self;
}

- (BOOL)initCodec {
    
    interface_ = vpx_codec_vp8_dx();
    vpx_codec_err_t ret = vpx_codec_dec_init(&ctx_, interface_, NULL, 0);
    if (ret != VPX_CODEC_OK) {
        [self codecDie:@"vpx_codec_dec_init error."];
        return NO;
    }
    return YES;
}

- (void)releaseCodec {
    
    if(vpx_codec_destroy(&ctx_))
        [self codecDie:@"Failed to destroy codec"];
}

- (void)decode:(uint8_t *)encData size:(int)encSize completion:(void(^)(uint8_t* decData, int decSize, int w, int h))completion {
    
    vpx_codec_err_t ret = vpx_codec_decode(&ctx_, (const uint8_t *)encData, encSize, NULL, 0);
    if (ret != VPX_CODEC_OK) {
        [self codecDie:@"vpx_codec_decode error."];
        return;
    }
    
    vpx_codec_iter_t iter = NULL;
	vpx_image_t* decImage = vpx_codec_get_frame(&ctx_, &iter);
    if (decImage == NULL) {
        [self codecDie:@"vpx_codec_decode error : vpx_image_t is NULL."];
        return;
    }
    
    NSLog(@"VP8 Decode size: %dx%d - DP : %dx%d", decImage->w, decImage->h, decImage->d_w, decImage->d_h);
    
    
    uint8_t* pBufferPlaneY = decImage->planes[VPX_PLANE_Y];
    uint8_t* pBufferPlaneU = decImage->planes[VPX_PLANE_U];
    uint8_t* pBufferPlaneV = decImage->planes[VPX_PLANE_V];

    int row = decImage->d_w;
    
    uint32_t y_data_size = row * decImage->d_h;
    uint8_t* y_data = malloc(y_data_size);
    uint8_t* y_data_p = y_data;
    for(int i=0;i<(decImage->d_h);i++) {
        memcpy(y_data_p, pBufferPlaneY, row);
        y_data_p +=row;
        pBufferPlaneY += decImage->stride[VPX_PLANE_Y];
    }
    
    row = (decImage->d_w + 1)>>1;
    uint32_t uv_data_size = row * ((decImage->d_h + 1) >> 1);
    uint8_t* u_data = malloc(uv_data_size);
    uint8_t* u_data_p = u_data;
    uint8_t* v_data = malloc(uv_data_size);
    uint8_t* v_data_p = v_data;
    for(int i=0;i<((decImage->d_h + 1)>>1);i++) {
        memcpy(u_data_p, pBufferPlaneU, row);
        memcpy(v_data_p, pBufferPlaneV, row);
        u_data_p+=row;
        v_data_p+=row;
        pBufferPlaneU += decImage->stride[VPX_PLANE_U];
        pBufferPlaneV += decImage->stride[VPX_PLANE_V];
    }
    
    memcpy(decodeBuffer_, y_data, y_data_size);
    memcpy(decodeBuffer_ + y_data_size, u_data, uv_data_size);
    memcpy(decodeBuffer_ + y_data_size + uv_data_size, v_data, uv_data_size);

    free(y_data);
    free(u_data);
    free(v_data);

    if (completion)
        completion(decodeBuffer_, y_data_size + (uv_data_size * 2), decImage->d_w, decImage->d_h);
    
}


- (void)codecDie:(NSString *)msg {
    const char *detail = vpx_codec_error_detail(&ctx_);
    NSLog(@"%@: %s, %s\n", msg, detail, vpx_codec_error(&ctx_));
}
@end
