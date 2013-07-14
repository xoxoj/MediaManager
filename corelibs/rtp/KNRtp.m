//
//  KNRtp.m
//  MediaManager
//
//  Created by cyh on 6/11/13.
//  Copyright (c) 2013 SH. All rights reserved.
//

#import "KNRtp.h"
#import "avcodec.h"
#import "intreadwrite.h"

static const uint8_t start_sequence[]   = { 0x00, 0x00, 0x00, 0x01 };
static const uint8_t RTP_H264_HEADER[]       = {0x80, 0xEE, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
static const uint8_t RTP_SPPEX_HEADER[] = {0x80, 0x61, 0xA7, 0x00, 0xE1, 0xFF, 0x00, 0x7E, 0x00, 0x00, 0x001, 0x08};        ///임시 고정 데이터.
#define RTP_HEADER_SIZE         12
#define STAP_A_PACKETIZE_ID     0x18

@interface KNRtp () {
    uint8_t* videoPacketizeBuffer_;
    int videoPacketizeBufferSize_;

    AVPacket packetizedPacket_;
    
    uint8_t* videoRTPBuffer_;
    int videoRTPBufferSize_;

    uint8_t* audioRTPBuffer_;
    int audioRTPBufferSize_;
}

@property (assign) uint16_t rtpVideoPacketSequence;
@property (assign) uint32_t rtpVideoPacketTimeStamp;
@property (assign) uint32_t rtpVideoSSRC;
@property (assign) uint16_t rtpAudioPacketSequence;
@property (assign) uint32_t rtpAudioPacketTimeStamp;
@property (assign) uint32_t rtpAudioSSRC;

- (uint32_t)makeSSRC;
- (int)nalSize:(x264_nal_t *)nals nalCount:(int)nalCount;

- (void)stap_a_packetize:(x264_nal_t *)nal nalCount:(int)nalCount packetizeBlock:(void(^)(uint8_t* packetizeData, int size))packetizeBlock;

- (void)stap_a_depacketize:(uint8_t *)encData size:(int)size depacketizeBlock:(void(^)(uint8_t* depacketizeData, int size))depacketizeBlock;

- (void)fu_a_depacketize:(AVPacket *)pkt;

@end


@implementation KNRtp

@synthesize rtpVideoPacketSequence      = _rtpVideoPacketSequence;
@synthesize rtpVideoPacketTimeStamp     = _rtpVideoPacketTimeStamp;
@synthesize rtpVideoSSRC                = _rtpVideoSSRC;
@synthesize rtpAudioPacketSequence      = _rtpAudioPacketSequence;
@synthesize rtpAudioPacketTimeStamp     = _rtpAudioPacketTimeStamp;
@synthesize rtpAudioSSRC                = _rtpAudioSSRC;

- (void)dealloc {
    
    if (videoPacketizeBuffer_) {
        free(videoPacketizeBuffer_);
        audioRTPBuffer_ = NULL;
    }
    
    if (videoRTPBuffer_) {
        free(videoRTPBuffer_);
        videoRTPBuffer_ = NULL;
    }
    
    if (audioRTPBuffer_) {
        free(audioRTPBuffer_);
        audioRTPBuffer_ = NULL;
    }
    
    [super dealloc];
}

- (uint32_t)makeSSRC {
   
    uint32_t ssrc = 0;
    
    uint8_t ssrc_seed = (uint8_t)arc4random() % 0xFF;
    memcpy(&ssrc + 0, &ssrc_seed, sizeof(uint8_t));

    ssrc_seed = (uint8_t)arc4random() % 0xFF;
    memcpy(&ssrc + 1, &ssrc_seed, sizeof(uint8_t));
    
    ssrc_seed = (uint8_t)arc4random() % 0xFF;
    memcpy(&ssrc + 2, &ssrc_seed, sizeof(uint8_t));
    
    ssrc_seed = (uint8_t)arc4random() % 0xFF;
    memcpy(&ssrc + 3, &ssrc_seed, sizeof(uint8_t));
    
    NSLog(@"KNRtp SSRC : %08X", ssrc);
    
    return ssrc;
}

-(int)nalSize:(x264_nal_t *)nals nalCount:(int)nalCount {
    
    int nalSize = 0;
    for (int i = 0; i < nalCount; i++) {
        nalSize += (int)nals[i].i_payload;
    }
    return nalSize;
}

- (void)videoPacketizeMode:(KNVideoPacketizeMode)mode
                      nals:(x264_nal_t *)nals
                  nalCount:(int)nalCount
            packetizeBlock:(void(^)(uint8_t* packetizeData, int size))packetizeBlock {
    
    int nalTotalSize = [self nalSize:nals nalCount:nalCount];
    if (nalTotalSize > videoPacketizeBufferSize_) {
        
        if (videoPacketizeBuffer_)
            free(videoPacketizeBuffer_);
        
        videoPacketizeBuffer_ = (uint8_t *)malloc(sizeof(uint8_t) * (nalTotalSize + 200));
    }
    
    
    if (mode == kKNPacketizeMode_STAP_A) {
        [self stap_a_packetize:nals nalCount:nalCount packetizeBlock:^(uint8_t *packetizeData, int size) {
            if (packetizeBlock)
                packetizeBlock(packetizeData, size);
        }];
        return;
    }
}

- (void)videoDePacketizeMode:(KNVideoPacketizeMode)mode data:(uint8_t *)data size:(int)size dePacketizeBlock:(void(^)(uint8_t* packetizeData, int size))dePacketizeBlock {
    
    if (mode == kKNPacketizeMode_STAP_A) {
        [self stap_a_depacketize:data size:size depacketizeBlock:^(uint8_t *depacketizeData, int size) {
            if (dePacketizeBlock) {
                dePacketizeBlock(depacketizeData, size);
            }
        }];
        return;
    }
}

- (void)appendVideoRTPHeader:(uint8_t *)data size:(int)size rtpBlock:(void(^)(uint8_t* rtpData, int size))rtpBlock {

    int rtpPacketSize = RTP_HEADER_SIZE + size;
    if (videoRTPBufferSize_ < rtpPacketSize) {
        if (videoRTPBuffer_)
            free(videoRTPBuffer_);
        
        videoRTPBufferSize_ = rtpPacketSize;
        videoRTPBuffer_ = (uint8_t *)malloc(sizeof(uint8_t) * videoRTPBufferSize_);
    }
    
    memcpy(videoRTPBuffer_, RTP_H264_HEADER, sizeof(RTP_H264_HEADER));
    
    uint16_t o_seq = htons(_rtpVideoPacketSequence);
    memcpy(videoRTPBuffer_ + 2, &o_seq, sizeof(uint16_t));
    ++_rtpVideoPacketSequence;
    
    uint32_t o_time = htonl(_rtpVideoPacketTimeStamp);
    memcpy(videoRTPBuffer_ + 4, &o_time, sizeof(uint32_t));
    _rtpVideoPacketTimeStamp += 1024;
    
    memcpy(videoRTPBuffer_ + sizeof(RTP_H264_HEADER), data, size);
    
    if (rtpBlock)
        rtpBlock(videoRTPBuffer_, sizeof(RTP_H264_HEADER) + size);
    
}

- (void)appendAudioRTPHeader:(uint8_t *)data size:(int)size rtpBlock:(void(^)(uint8_t* rtpData, int size))rtpBlock {

    int rtpPacketSize = RTP_HEADER_SIZE + size;
    if (audioRTPBufferSize_ < rtpPacketSize) {
        if (audioRTPBuffer_)
            free(audioRTPBuffer_);
        
        audioRTPBufferSize_ = rtpPacketSize;
        audioRTPBuffer_ = (uint8_t *)malloc(sizeof(uint8_t) * audioRTPBufferSize_);
    }
    
    memcpy(audioRTPBuffer_, RTP_SPPEX_HEADER, sizeof(RTP_SPPEX_HEADER));
    
    uint16_t o_seq = htons(_rtpAudioPacketSequence);
    memcpy(audioRTPBuffer_ + 2, &o_seq, sizeof(uint16_t));
    ++_rtpAudioPacketSequence;
    
    uint32_t o_time = htonl(_rtpAudioPacketTimeStamp);
    memcpy(audioRTPBuffer_ + 4, &o_time, sizeof(uint32_t));
    _rtpAudioPacketTimeStamp += 320;

    memcpy(audioRTPBuffer_ + sizeof(RTP_SPPEX_HEADER), data, size);
    
    
    if (rtpBlock)
        rtpBlock(audioRTPBuffer_, size + sizeof(RTP_SPPEX_HEADER));
}

- (void)stap_a_packetize:(x264_nal_t *)nal nalCount:(int)nalCount packetizeBlock:(void(^)(uint8_t* packetizeData, int size))packetizeBlock {

    videoPacketizeBuffer_[0] = STAP_A_PACKETIZE_ID;
    
    int written = 1;
    for (int i = 0; i < nalCount; i++) {
        uint8_t* nalData   = nal[i].p_payload;
        int nalSize        = nal[i].i_payload;
        
        int j = 0;
        for (j = 0; j < 3; j++) {
            if (nalData[j] != 0x00)
                break;
        }
        if (j > 0)
            ++j;
        
        
        uint16_t nalunitSize = nalSize - j;
        nalunitSize = htons(nalunitSize);
        memcpy(videoPacketizeBuffer_ + written, &nalunitSize, sizeof(uint16_t));
        written += 2;
        
        memcpy(videoPacketizeBuffer_ + written, nalData + j, nalSize - j);
        written += (nalSize - j);
    }


    if (packetizeBlock)
        packetizeBlock(videoPacketizeBuffer_, written);
}

- (void)stap_a_depacketize:(uint8_t *)encData size:(int)size depacketizeBlock:(void(^)(uint8_t* depacketizeData, int size))depacketizeBlock {

    if (encData[0] != STAP_A_PACKETIZE_ID) {
        NSLog(@"Not stap-a packetize. (%02X)", encData[0]);
        return;
    }
    
    uint8_t* buff = encData;
    int len = size;
    
    buff++;
    len--;
    
    int total_length = 0;
    char base64packet[1024 * 100];
    char* dst = base64packet;
    
    
    for (int pass = 0; pass < 2; pass++) {
        
        const uint8_t* src = buff;
        int src_len = len;
        
        while (src_len > 2) {
            
            uint16_t nal_size = AV_RB16(src);
            
            src += 2;
            src_len -= 2;
            
            if (nal_size <= src_len) {
                if (pass == 0) {
                    total_length += sizeof(start_sequence) + nal_size;
                } else {
                    assert(dst);
                    memcpy(dst, start_sequence, sizeof(start_sequence));
                    dst += sizeof(start_sequence);
                    memcpy(dst, src, nal_size);
                    dst += nal_size;
                }
            } else {
                NSLog(@"nal size exceeds length: %d %d\n", nal_size, src_len);
            }
            
            src += nal_size;
            src_len -= nal_size;
            
            if (src_len < 0)
                NSLog(@"Consumed more bytes than we got! (%d)\n", src_len);
        }
        
        if (pass == 0) {
            //            av_free_packet(&stapA_Packet_);
            //            av_new_packet(&nalPacket_, total_length);
            //            dst = stapA_Packet_.data;
            packetizedPacket_.data = (uint8_t *)dst;
            packetizedPacket_.size = total_length;
            packetizedPacket_.stream_index = 0;
            
        }
    }
    
    if (depacketizeBlock)
        depacketizeBlock(packetizedPacket_.data, packetizedPacket_.size);
}

- (void)fu_a_depacketize:(AVPacket *)pkt {
    
    uint8_t* buf = pkt->data;
    int len = pkt->size;
    uint8_t nal = buf[0];
    
    buf++;
    len--;
    
    uint8_t fu_indicator = nal;
    uint8_t fu_header = *buf;
    uint8_t start_bit = fu_header >> 7;
    
    uint8_t nal_type = (fu_header & 0x1f);
    uint8_t reconstructed_nal;
    
    reconstructed_nal = fu_indicator & (0xe0);
    reconstructed_nal |= nal_type;
    
    
    buf++;
    len--;
    

    if(start_bit) {
        // copy in the start sequence, and the reconstructed nal....
        av_new_packet(&packetizedPacket_, sizeof(start_sequence)+sizeof(nal)+len);
        memcpy(packetizedPacket_.data, start_sequence, sizeof(start_sequence));
        pkt->data[sizeof(start_sequence)] = reconstructed_nal;
        memcpy(packetizedPacket_.data+sizeof(start_sequence)+sizeof(nal), buf, len);
    } else {
        av_new_packet(&packetizedPacket_, len);
        memcpy(packetizedPacket_.data, buf, len);
    }
}

@end
