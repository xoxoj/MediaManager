//
//  KNAudioRingQueue.m
//  Aruts
//
//  Created by ken on 13. 5. 21..
//
//

#import "KNAudioRingQueue.h"


@interface KNAudioRingQueue ()
@property (assign) uint8_t* buffer;
@property (assign) int bufferSize;
@property (assign) int written;
@property (assign) int seek;

@property (assign) uint8_t* readBuffer;
@property (assign) int readBufferSize;
@end

@implementation KNAudioRingQueue

@synthesize buffer          = _buffer;
@synthesize bufferSize      = _bufferSize;
@synthesize written         = _written;
@synthesize seek            = _seek;

@synthesize readBuffer      = _readBuffer;
@synthesize readBufferSize  = _readBufferSize;

- (void)dealloc {
    
    if (_buffer) {
        free(_buffer);
        _buffer = NULL;
    }
    
    if (_readBuffer) {
        free(_readBuffer);
        _buffer = NULL;
    }
    
    _bufferSize = _written = _seek = 0;
    
    [super dealloc];
}

- (id)initWithBufferSize:(int)size {
    self = [super init];
    if (self) {
        if (size <= 0)
            size = kMegaByte * 2;
        
        _bufferSize = size;
        _buffer = (uint8_t *)malloc(sizeof(uint8_t) * size);
        memset(_buffer, 0, sizeof(uint8_t) * size);
        
        _readBuffer = NULL;
    }
    return self;
}

- (void)write:(uint8_t *)pSrcBuffer size:(int)size completion:(void(^)(void))completion {
    
    @synchronized(self) {
        if ( (_bufferSize - _written) >= size) {
            memcpy(_buffer + _written, pSrcBuffer, sizeof(uint8_t) * size);
            _written += size;
        } else {
            
            int canWrite = _bufferSize - _written;
            memcpy(_buffer + _written, pSrcBuffer, sizeof(uint8_t) * canWrite);
            
            int srcTail = size - canWrite;
            memcpy(_buffer + 0, pSrcBuffer + canWrite, sizeof(uint8_t) * srcTail);
            _written = srcTail;
        }
    }
    
    if (completion) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion();
        });
    }
}

- (void)read:(int)size readBlock:(void(^)(uint8_t* buffer, int readSize))readBlock {
    
    //경계체크.
    int ringWritten = _written;
    if (ringWritten < _seek) {
        ringWritten += _bufferSize;
    }

    if ((ringWritten - _seek) < size) {
        usleep(1000 * 2);
        return;
    }
    
    @synchronized(self) {
    
        if (_readBuffer == NULL) {
            _readBuffer = (uint8_t *)malloc(sizeof(uint8_t) * size);
            _readBufferSize = size;
        } else if (_readBufferSize != size) {
            free(_readBuffer);
            _readBufferSize = size;
            _readBuffer = (uint8_t *)malloc(sizeof(uint8_t) * _readBufferSize);
        }
    
            
        int canRead = _bufferSize - _seek;
        
        if (canRead >= size) {
            memcpy(_readBuffer, _buffer + _seek, sizeof(uint8_t) * size);
            _seek += size;
        } else {
            memcpy(_readBuffer, _buffer + _seek, sizeof(uint8_t) * canRead);
            
            int srcTail = size - canRead;
            memcpy(_readBuffer + canRead, _buffer + 0, sizeof(uint8_t) * srcTail);
            _seek = srcTail;
        }
    }
    
    if (readBlock) {
        readBlock(_readBuffer, size);
    }
}
@end
