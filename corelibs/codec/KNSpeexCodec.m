//
//  KNSpeexCodec.m
//  Aruts
//
//  Created by ken on 13. 5. 20..
//
//

#import "KNSpeexCodec.h"
#import "speex.h"
#import "speex_preprocess.h"

#define MAX_NB_BYTE             200
#define DECODE_BUFFER_SIZE      1024

@interface KNSpeexCodec () {
    char cbits_[MAX_NB_BYTE];
    
    uint8_t* decodeBuffer_;
    int decodeBufferSize_;
}

@property (assign) KnSpeexBandwidth bandwidth;
@property (assign) int quality;

@property (assign) void* encoderState;
@property (assign) int encFrameSize;
@property (assign) SpeexBits* pEncBits;
@property (assign) spx_int16_t* pEncBuffer;


@property (assign) void* decoderState;
@property (assign) int decFrameSize;
@property (assign) SpeexBits* pDecBits;
@property (assign) spx_int16_t* pDecBuffer;


- (void)initEncoder;
- (void)initDecoder;

@end

@implementation KNSpeexCodec

@synthesize bandwidth       = _bandwidth;
@synthesize quality         = _quality;

@synthesize encoderState    = _encoderState;
@synthesize encFrameSize    = _encFrameSize;
@synthesize pEncBits        = _pEncBits;
@synthesize pEncBuffer      = _pEncBuffer;

@synthesize decoderState    = _decoderState;
@synthesize decFrameSize    = _decFrameSize;
@synthesize pDecBits        = _pDecBits;
@synthesize pDecBuffer      = _pDecBuffer;


- (void)dealloc {
    
    if(_encoderState) {
		speex_encoder_destroy(_encoderState);
        _encoderState = NULL;
        _encFrameSize = 0;
        
        if (_pEncBits) {
            free(_pEncBits);
            _pEncBits = NULL;
        }
        
        if (_pEncBuffer) {
            free(_pEncBuffer);
            _pEncBuffer = NULL;
        }
        
    }
    
    if(_decoderState) {
        
		speex_decoder_destroy(_decoderState);
        _decoderState = NULL;
        _decFrameSize = 0;

        if (_pDecBits) {
            free(_pDecBits);
            _pDecBits = NULL;
        }
        
        if (_pDecBuffer) {
            free(_pDecBuffer);
            _pDecBuffer = NULL;
        }
    }
    
    
    if (decodeBuffer_) {
        free(decodeBuffer_);
        decodeBuffer_ = NULL;
    }

    [super dealloc];
}

- (id)initWithBandwidth:(KnSpeexBandwidth)band quality:(int)q {
    self = [super init];
    if (self) {
        
        _bandwidth = band;
        _quality = q;
        if (_quality <= 0)
            _quality = 1;
        
        if (_quality > 10)
            _quality = 10;
    
        [self initDecoder];
        [self initEncoder];
    }
    return self;
}

- (void)encode:(int16_t *)rawBuff size:(int)rawSize completion:(void(^)(uint8_t* encBuff, int encSize))completion {

    @synchronized(_encoderState) {
        
        memcpy(_pEncBuffer, rawBuff, _encFrameSize);
        
        speex_bits_reset(_pEncBits);
        speex_encode_int(_encoderState, (spx_int16_t *)rawBuff, _pEncBits);
        int nbBytes = speex_bits_write(_pEncBits, cbits_, MAX_NB_BYTE);
        if (completion) {
            completion((uint8_t *)cbits_, nbBytes);
        }

    }
}

- (void)decode:(uint8_t *)encBuff size:(int)encSize completion:(void(^)(int16_t* rawBuff, int rawSize))completion {

    @synchronized(_decoderState) {
        
        if (decodeBuffer_ == NULL) {
            decodeBufferSize_ = DECODE_BUFFER_SIZE;
            decodeBuffer_ = (uint8_t *)malloc(sizeof(uint8_t) * decodeBufferSize_);
        }
        
        if (decodeBufferSize_ < encSize) {
            free(decodeBuffer_);
            
            decodeBufferSize_ = encSize;
            decodeBuffer_ = (uint8_t *)malloc(sizeof(uint8_t) * decodeBufferSize_);
        }
        int copySize = encSize;
        memcpy(decodeBuffer_, encBuff, copySize);
        
        int ret = 0;
        speex_bits_read_from(_pDecBits, (char *)decodeBuffer_, copySize);
        ret = speex_decode_int(_decoderState, _pDecBits, _pDecBuffer);

        if (completion) {
            completion(_pDecBuffer, _decFrameSize);
        }
    }
}


- (void)initEncoder {
    
    spx_int32_t tmp = 0;
    int bitrate = 16000;
    
	if(_bandwidth == kSpeexUltraWide)
	{
		_encoderState = speex_encoder_init(speex_lib_get_mode(SPEEX_MODEID_UWB));
		speex_encoder_ctl(_encoderState, SPEEX_SET_COMPLEXITY, &tmp);
        bitrate = 32000;
	}
	else if(_bandwidth == kSpeexWide)
	{
		_encoderState = speex_encoder_init(speex_lib_get_mode(SPEEX_MODEID_WB));
		speex_encoder_ctl(_encoderState, SPEEX_SET_COMPLEXITY, &tmp);
        bitrate = 16000;
	}
	else
	{
		_encoderState = speex_encoder_init(speex_lib_get_mode(SPEEX_MODEID_NB));
		speex_encoder_ctl(_encoderState, SPEEX_SET_COMPLEXITY, &tmp);
        bitrate = 8000;
	}
    speex_encoder_ctl(_encoderState, SPEEX_SET_BITRATE, &bitrate);
	speex_encoder_ctl(_encoderState, SPEEX_SET_QUALITY, &_quality);
	speex_encoder_ctl(_encoderState, SPEEX_GET_FRAME_SIZE, &_encFrameSize);

    _pEncBits = (SpeexBits*) malloc(sizeof(SpeexBits));
	speex_bits_init(_pEncBits);
    
	if (_pEncBuffer)
	{
		free(_pEncBuffer);
		_pEncBuffer = NULL;
	}
	_pEncBuffer = (spx_int16_t *)malloc(sizeof(spx_int16_t) * _encFrameSize);
    
    NSLog(@"@speex ecorder - frameSize : %d", _encFrameSize);
}

- (void)initDecoder {
    
    spx_int32_t tmp = 1;
    if(_bandwidth == kSpeexUltraWide)
	{
		_decoderState = speex_decoder_init(speex_lib_get_mode(SPEEX_MODEID_UWB));
	}
	else if(_bandwidth == kSpeexWide)
	{
		_decoderState = speex_decoder_init(speex_lib_get_mode(SPEEX_MODEID_WB));
	}
	else
	{
		_decoderState = speex_decoder_init(speex_lib_get_mode(SPEEX_MODEID_NB));
	}
    
	speex_decoder_ctl(_decoderState, SPEEX_SET_ENH, &tmp);
	speex_decoder_ctl(_decoderState, SPEEX_GET_FRAME_SIZE, &_decFrameSize);
    _pDecBits = (SpeexBits*) malloc(sizeof(SpeexBits));
	speex_bits_init(_pDecBits);
    
	if (_pDecBuffer)
	{
		free(_pDecBuffer);
		_pDecBuffer = NULL;
	}
	_pDecBuffer = (spx_int16_t *)malloc(sizeof(spx_int16_t) * _decFrameSize);
    
    NSLog(@"@speex decoder - frameSize : %d", _decFrameSize);
}

@end
