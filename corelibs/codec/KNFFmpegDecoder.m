//
//  KNFFmpegDecoder.m
//  GLKDrawTest
//
//  Created by Choi Yeong Hyeon on 12. 11. 25..
//  Copyright (c) 2012년 Choi Yeong Hyeon. All rights reserved.
//

#import "KNFFmpegDecoder.h"
#import "avformat.h"
#import "swscale.h"
#import "swresample.h"
#import "intreadwrite.h"

#define BUFFER_SIZE      1024 * 500

@interface KNFFmpegDecoder() {

    AVCodecContext* pVideoCodeCtx_;
    AVCodec* pVideoCodec_;
    AVFrame* pVideoFrame_;


    AVCodecContext* pAudioCodeCtx_;
    AVCodec* pAudioCodec_;
    AVFrame* pAudioFrame_;
    
    
    uint8_t* yuvBuffer_;
    int yuvBufferSize_;
    
    AVPacket encPacket_;
    AVPacket nalPacket_;
    
    
    uint8_t* decodeBuffer_;
    int decodeBufferSize_;
}

- (NSData *)copYUVData:(UInt8 *)src
              linesize:(int)linesize
                 width:(int)width
                height:(int)height;
- (NSDictionary *)makeFrameData;

- (int)resampleingAudioToS16:(uint8_t** )pBuffer;
- (NSDictionary *)makeAudioData:(uint8_t *)buffer size:(int)size;
- (int)makeYuv420PlaneBuffer:(AVFrame *)encFrame;
@end

@implementation KNFFmpegDecoder


- (void)dealloc {
    
    if (pVideoFrame_) {
        av_free(pVideoFrame_);
        pVideoFrame_ = NULL;
    }
    
    if (pAudioFrame_) {
        av_free(pAudioFrame_);
        pAudioFrame_ = NULL;
    }
    
    if (yuvBuffer_) {
        free(yuvBuffer_);
        yuvBuffer_ = NULL;
    }
    
    
    av_free_packet(&encPacket_);
//    av_free_packet(&stapA_Packet_);
    
    if (decodeBuffer_) {
        free(decodeBuffer_);
        decodeBuffer_ = NULL;
        decodeBufferSize_ = 0;
    }
    
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self) {
        decodeBufferSize_ = BUFFER_SIZE;
        decodeBuffer_ = (uint8_t *)malloc(sizeof(uint8_t) * decodeBufferSize_);
    }
    return self;
}

- (id)initWithVideoCodecID:(enum AVCodecID)vcodecid
              audioCodecID:(enum AVCodecID)acodecid {

    self = [self init];
    if (self) {
        
        av_register_all();
        avcodec_register_all();

        //init video codec.
        if (vcodecid > kNoCodec) {
            
            pVideoCodec_ = avcodec_find_decoder(vcodecid);
            if (pVideoCodec_ == NULL) {
                NSLog(@"%s Video decoder find error1.", __func__);
                [self release];
                return nil;
            }
            
            pVideoCodeCtx_ = avcodec_alloc_context3(pVideoCodec_);
            if (!pVideoCodeCtx_) {
                NSLog(@"%s Video decoder find error2.", __func__);
                [self release];
                return nil;
            }
            
            if (avcodec_open2(pVideoCodeCtx_, pVideoCodec_, NULL) < 0) {
                NSLog(@"%s Video decoder open error3.", __func__);
                [self release];
                return nil;
            }
            pVideoFrame_ = avcodec_alloc_frame();
        }
        
        
        ///init audio codec.
        if (acodecid > kNoCodec) {
            
            pAudioCodec_ = avcodec_find_decoder(acodecid);
            if (pAudioCodec_ == NULL) {
                NSLog(@"%s Audio decoder find error.", __func__);
                [self release];
                return nil;
            }
            
            pAudioCodeCtx_ = avcodec_alloc_context3(pAudioCodec_);
            if (!pAudioCodeCtx_) {
                NSLog(@"%s Audio decoder find error.", __func__);
                [self release];
                return nil;
            }

            
            if (avcodec_open2(pAudioCodeCtx_, pAudioCodec_, NULL) < 0) {
                NSLog(@"%s Audio decoder open error.", __func__);
                [self release];
                return nil;
            }
            pAudioFrame_ = avcodec_alloc_frame();
        }
    }
    return self;
}


- (void)decodeVideo2:(AVPacket *)packet
          completion:(void(^)(uint8_t* data, int size, int w, int h))completion {

    @synchronized(self) {
        int got_picture = 0;
        
        int len = avcodec_decode_video2(pVideoCodeCtx_, pVideoFrame_, &got_picture, packet);
        
        if (len < 0) {
            NSLog(@"avcodec_decode_video2 error : len : %d", len);
            if (completion)
                completion(NULL, 0, 0, 0);
            return;
        }
        
        if (!got_picture) {
            NSLog(@"avcodec_decode_video2 error : got_picture_ptr : %d", got_picture);
            if (completion)
                completion(NULL, 0, 0, 0);
            return;
        }
        
        if (completion) {
            int yuvSize = [self makeYuv420PlaneBuffer:pVideoFrame_];
            completion(yuvBuffer_, yuvSize, pVideoFrame_->width, pVideoFrame_->height);
        }
    }
}

- (void)decodeVideo3:(uint8_t *)encData size:(int)size
          completion:(void(^)(uint8_t* data, int size, int w, int h))completion {
    
    AVPacket packet;
    av_new_packet(&packet, size);
    memcpy(packet.data, encData, size);
    
    [self decodeVideo2:&packet completion:completion];
    
    av_free_packet(&packet);
}


- (void)decodeVideo:(AVPacket *)packet
         completion:(void(^)(NSDictionary* frameData))completion {

    int got_picture = 0;

    int len = avcodec_decode_video2(pVideoCodeCtx_, pVideoFrame_, &got_picture, packet);

    if (len < 0) {
        NSLog(@"avcodec_decode_video2 error : len : %d", len);
        return;
    }
    
    if (!got_picture) {
        NSLog(@"avcodec_decode_video2 error : got_picture_ptr : %d", got_picture);
        return;
    }

    if (completion) {
        @autoreleasepool {
            NSDictionary* frameData = [[self makeFrameData] retain];;
            completion(frameData);
            [frameData release];
        }
    }
}


- (void)decodeAudio:(AVPacket *)packet
         completion:(void(^)(NSDictionary* frameData))completion {

    @synchronized(self) {
        int got_picture = 0;
        
        int len = avcodec_decode_audio4(pAudioCodeCtx_, pAudioFrame_, &got_picture, packet);

        if (len < 0) {
            NSLog(@"avcodec_decode_audio4 error : len : %d", len);
            return;
        }
        
        if (!got_picture) {
            NSLog(@"avcodec_decode_audio4 error : got_picture_ptr : %d", got_picture);
            return;
        }
        
        if (pAudioCodeCtx_->sample_fmt != AV_SAMPLE_FMT_S16) {
            
            uint8_t* pBuffer = NULL;
            int len = [self resampleingAudioToS16:&pBuffer];
            if (len <= 0) {
                if (pBuffer)
                    free(pBuffer);
                return;
            }
            
            NSDictionary* audio = [self makeAudioData:pBuffer size:len];
            [audio retain];

            if (pBuffer)
                free(pBuffer);
            pBuffer = NULL;
            
            if (completion) {
                completion(audio);
                [audio release];
            }
            
        } else {
            
            if (completion) {
                int decSize = av_samples_get_buffer_size(NULL,
                                                         pAudioCodeCtx_->channels,
                                                         pAudioFrame_->nb_samples,
                                                         pAudioCodeCtx_->sample_fmt,
                                                         1);
                
                NSMutableData *md = [NSMutableData dataWithLength:len];
                Byte *dst = md.mutableBytes;
                memcpy(dst, pAudioFrame_->data[0], decSize);
                
                NSMutableDictionary* decData = [[NSMutableDictionary alloc] initWithCapacity:2];
                [decData setObject:[NSNumber numberWithInt:decSize] forKey:@"size"];
                [decData setObject:decData forKey:@"data"];
                [md release];
                
                completion(decData);
                [decData release];
            }
        }
    }
}


- (void)endDecode {
    
    avcodec_close(pVideoCodeCtx_);
    av_free(pVideoFrame_);
    pVideoFrame_ = NULL;
    
    avcodec_close(pAudioCodeCtx_);
    av_free(pAudioFrame_);
    pAudioFrame_ = NULL;
}

- (NSDictionary *)makeFrameData {

    NSMutableDictionary* frameData = [NSMutableDictionary dictionary];
    [frameData setObject:[NSNumber numberWithInt:pVideoCodeCtx_->width] forKey:kKNFFDecKeyWidth];
    [frameData setObject:[NSNumber numberWithInt:pVideoCodeCtx_->height] forKey:kKNFFDecKeyHeigth];

    NSData* ydata = [self copYUVData:pVideoFrame_->data[0] linesize:pVideoFrame_->linesize[0] width:pVideoCodeCtx_->width height:pVideoCodeCtx_->height];
    NSData* udata = [self copYUVData:pVideoFrame_->data[1] linesize:pVideoFrame_->linesize[1] width:pVideoCodeCtx_->width/2 height:pVideoCodeCtx_->height/2];
    NSData* vdata = [self copYUVData:pVideoFrame_->data[2] linesize:pVideoFrame_->linesize[2] width:pVideoCodeCtx_->width/2 height:pVideoCodeCtx_->height/2];
    [frameData setObject:ydata forKey:kKNFFDecKeyLuma];
    [frameData setObject:udata forKey:kKNFFDecKeyChromaB];
    [frameData setObject:vdata forKey:kKNFFDecKeyChromaR];

    return frameData;
}

- (NSData *)copYUVData:(UInt8 *)src linesize:(int)linesize width:(int)width height:(int)height {

    width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength: width * height];
    Byte *dst = md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    return md;
}

- (int)copyYUVBuffer:(uint8_t *)src dst:(uint8_t**)dst linesize:(int)linesize w:(int)w h:(int)h {
    
    w = MIN(linesize, w);
    int buffSize = w * h;
    
    *dst = (uint8_t *)malloc(sizeof(uint8_t) * buffSize);
    uint8_t* buffer = *dst;
    
    for (int i = 0; i < h; i++) {
        memcpy(buffer, src, w);
        buffer += w;
        src += linesize;
    }
    return  buffSize;
}

- (int)resampleingAudioToS16:(uint8_t** )pBuffer {
    
    const int AVCODEC_MAX_AUDO_FRAME_SIZE = 1130496;
    
    int dataSize = av_samples_get_buffer_size(NULL,
                                              pAudioCodeCtx_->channels,
                                              pAudioFrame_->nb_samples,
                                              pAudioCodeCtx_->sample_fmt,
                                              1);
    
    SwrContext* pCVTContext = NULL;
    pCVTContext = swr_alloc_set_opts(pCVTContext,
                                     pAudioCodeCtx_->channel_layout,
                                     AV_SAMPLE_FMT_S16,
                                     pAudioCodeCtx_->sample_rate,
                                     pAudioCodeCtx_->channel_layout,
                                     pAudioCodeCtx_->sample_fmt,
                                     pAudioCodeCtx_->sample_rate,
                                     0,
                                     0);
    
    int err = -1;
    if ( (err = swr_init(pCVTContext)) < 0) {
        if (err == AVERROR(EINVAL))
            NSLog(@"Failed to initialize the resampleing context.");
    }
    
    uint8_t cvtBuffer[AVCODEC_MAX_AUDO_FRAME_SIZE];
    uint8_t* pOut[] = {cvtBuffer};
    
    const uint8_t* pIn[SWR_CH_MAX] = {0,};
    if (!av_sample_fmt_is_planar(pAudioCodeCtx_->sample_fmt)) {
        pIn[0] = pAudioFrame_->data[0];
    } else {
        pIn[0] = pAudioFrame_->data[0];
        pIn[1] = pAudioFrame_->data[0];
        pIn[2] = pAudioFrame_->data[0];
        pIn[3] = pAudioFrame_->data[0];
        pIn[4] = pAudioFrame_->data[0];
        pIn[5] = pAudioFrame_->data[0];
        pIn[6] = pAudioFrame_->data[0];
        pIn[7] = pAudioFrame_->data[0];
        pIn[8] = pAudioFrame_->data[0];
    }
    
    int ret = swr_convert(pCVTContext, pOut, pAudioFrame_->nb_samples, pIn, pAudioFrame_->nb_samples);
    if (ret <= 0)
        return 0;
    
    dataSize = av_samples_get_buffer_size(NULL, pAudioCodeCtx_->channels, pAudioFrame_->nb_samples, AV_SAMPLE_FMT_S16, 1);
    if (dataSize > AVCODEC_MAX_AUDO_FRAME_SIZE && dataSize <= 0)
        return 0;
    
    *pBuffer = (uint8_t *)malloc(sizeof(uint8_t) * dataSize);
    memcpy(*pBuffer, &cvtBuffer, dataSize);
    
    swr_free(&pCVTContext);
    
    return dataSize;
}

- (NSDictionary *)makeAudioData:(uint8_t *)buffer size:(int)size {

    NSMutableData *md = [NSMutableData dataWithLength:size];
    Byte *dst = md.mutableBytes;
    memcpy(dst, buffer, size);
    
    
    NSMutableDictionary* audioData = [[NSMutableDictionary alloc] initWithCapacity:2];
    [audioData setObject:[NSNumber numberWithInt:size] forKey:@"size"];
    [audioData setObject:md forKey:@"data"];
    
    return [audioData autorelease];
}

- (int)makeYuv420PlaneBuffer:(AVFrame *)encFrame {
    
    int yWidth = MIN(encFrame->linesize[0], encFrame->width);
    int ySize = yWidth * encFrame->height;

    int uWidth = MIN(encFrame->linesize[1], encFrame->width / 2);
    int uSize = uWidth * (encFrame->height / 2);

    int vWidth = MIN(encFrame->linesize[2], encFrame->width / 2);
    int vSize = vWidth * encFrame->height / 2;
    
    if (yuvBuffer_ == NULL) {
        yuvBufferSize_ = (encFrame->width * encFrame->height * 3) >> 1;
        yuvBuffer_ = (uint8_t *)malloc(sizeof(uint8_t) * yuvBufferSize_);
    }
    
    int newYuvBufferSize = (encFrame->width * encFrame->height * 3) >> 1;
    if (newYuvBufferSize > yuvBufferSize_) {
        NSLog(@"YUV Buffer size changed. (%d:%d)", yuvBufferSize_, newYuvBufferSize);
        yuvBufferSize_ = newYuvBufferSize;
        free(yuvBuffer_);
        yuvBuffer_ = (uint8_t *)malloc(sizeof(uint8_t) * yuvBufferSize_);
    }
    
    ///Copy Y data
    uint8_t* tmpDst = yuvBuffer_;
    uint8_t* tmpSrc = encFrame->data[0];
    for (int i = 0; i < encFrame->height; i++) {
        memcpy(tmpDst, tmpSrc, yWidth);
        tmpDst += yWidth;
        tmpSrc += encFrame->linesize[0];
    }

    ///Copy U data
    tmpDst = yuvBuffer_ + ySize;
    tmpSrc = encFrame->data[1];
    for (int i = 0; i < encFrame->height / 2; i++) {
        memcpy(tmpDst, tmpSrc, uWidth);
        tmpDst += uWidth;
        tmpSrc += encFrame->linesize[1];
    }

    ///Copy V data
    tmpDst = yuvBuffer_ + ySize + uSize;
    tmpSrc = encFrame->data[2];
    for (int i = 0; i < encFrame->height / 2; i++) {
        memcpy(tmpDst, tmpSrc, vWidth);
        tmpDst += vWidth;
        tmpSrc += encFrame->linesize[2];
    }

    return (ySize + uSize + vSize);
}

@end

