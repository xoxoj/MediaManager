//
//  KNVideoManager.m
//  iMultiviewCPSLib
//
//  Created by ken on 13. 5. 22..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import "KNVideoManager.h"
#import "KNImageConvert.h"
#import <Accelerate/Accelerate.h>
#import <CoreImage/CoreImage.h>

const NSInteger MAX_CAPTURE_FRAMERATE   = 30;
const NSInteger SECOND                  = 1;
const NSInteger DEFAULT_FRAMERATE       = 30;

@interface KNVideoManager () {
    void(^captureOutputBlock_)(uint8_t* data, int len, int w, int h);
    void(^previewRenderBlock_)(uint8_t* data, int w, int h);
}
@property (assign) AVCaptureDevicePosition devicePostion;
@property (retain, nonatomic) AVCaptureSession* session;
@property (retain, nonatomic) AVCaptureVideoPreviewLayer* previewLayer;
@property (retain, nonatomic) UIView* viewPreview;
@property (retain, nonatomic) KNImageConvert* imgConvert;
@property (assign) NSInteger captureFrameRate;
@property (assign) BOOL torchModeAuto;
@property (assign) BOOL mirriring;
@property (assign) KNCaptureResolution captureResolution;
@property (assign) KNRawDataType rawDataType;

- (AVCaptureSession *)initSession;
- (AVCaptureDevice *)cameraPosition:(AVCaptureDevicePosition)position;
- (NSString *)preset:(KNCaptureResolution)resolution;
- (AVCaptureDeviceInput *)currentInput;
- (AVCaptureVideoDataOutput *)currentOutput;
- (void)removeCurrentInput;
- (void)removeCurrentOutput;
- (void)changeFrameRate:(AVCaptureConnection *)conn;
- (CGImageRef)imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer;
- (void)autoTorch;
- (void)rotateBuffer:(CMSampleBufferRef)sampleBuffer completion:(void(^)(uint8_t* data, int len, int w, int h))completion;

- (void)rgbToYuv420:(CMSampleBufferRef)sampleBuffer completion:(void(^)(uint8_t* yuv420p, int len, int w, int h))completion;
- (void)yuv420PlanarToYuv420:(CMSampleBufferRef)sampleBuffer completion:(void(^)(uint8_t* yuv420p, int len, int w, int h))completion;

@end


@implementation KNVideoManager

@synthesize cameraPosition      = _cameraPosition;
@synthesize videoOrientation    = _videoOrientation;
@synthesize captureSize         = _captureSize;

@synthesize devicePostion       = _devicePostion;
@synthesize torchModeAuto       = _torchModeAuto;
@synthesize mirriring           = _mirriring;
@synthesize session             = _session;
@synthesize previewLayer        = _previewLayer;
@synthesize viewPreview         = _viewPreview;
@synthesize captureFrameRate    = _captureFrameRate;
@synthesize captureResolution   = _captureResolution;
@synthesize rawDataType         = _rawDataType;
@synthesize imgConvert          = _imgConvert;

- (void)dealloc{
    [_previewLayer release];
    [_viewPreview release];
    [_session release];
    
    [_imgConvert release];
    
    if (captureOutputBlock_) {
        [captureOutputBlock_ release];
        captureOutputBlock_ = nil;
    }
    
    if (previewRenderBlock_) {
        [previewRenderBlock_ release];
        previewRenderBlock_ = nil;
    }
    
    [super dealloc];
}

- (id)initWidthImageConvert:(KNImageConvert *)convert {
    self = [super init];
    if (self) {
        self.imgConvert = convert;
    }
    return self;
}

#pragma mark - Private
- (AVCaptureDevice *)cameraPosition:(AVCaptureDevicePosition)position {
    
    for (AVCaptureDevice* device in [AVCaptureDevice devices]) {
        if ([device hasMediaType:AVMediaTypeVideo]) {
            if (device.position == position)
                return device;
        }
    }
    return nil;
}

- (NSString *)preset:(KNCaptureResolution)resolution {
    
    NSString* preset = AVCaptureSessionPresetMedium;
    
    switch (resolution) {
        case kKNCaptureHigh:
            preset = AVCaptureSessionPresetHigh;
            break;
            
        case kKNCaptureMedium:
            preset = AVCaptureSessionPresetMedium;
            break;
            
        case kKNCaptureLow:
            preset = AVCaptureSessionPresetLow;
            break;
            
        case kKNCapture288:
            preset = AVCaptureSessionPreset352x288;
            break;
            
        case kKNCapture480:
            preset = AVCaptureSessionPreset640x480;
            break;
            
        case kKNCapture720:
            preset = AVCaptureSessionPreset1280x720;
            break;
            
        case kKNCapture1080:
            preset = AVCaptureSessionPreset1920x1080;
            break;
    }
    
    return preset;
}

- (AVCaptureDeviceInput *)currentInput {
    return [_session.inputs objectAtIndex:0];
}

- (AVCaptureVideoDataOutput *)currentOutput {
    return [_session.outputs objectAtIndex:0];
}

- (void)removeCurrentInput {
    [_session removeInput:[self currentInput]];
}

- (void)removeCurrentOutput {
    [_session removeOutput:[self currentOutput]];
}

- (void)changeFrameRate:(AVCaptureConnection *)conn {
    
    if (conn.supportsVideoMinFrameDuration)
        conn.videoMinFrameDuration = CMTimeMake(SECOND, _captureFrameRate);
    if (conn.supportsVideoMaxFrameDuration)
        conn.videoMaxFrameDuration = CMTimeMake(SECOND, _captureFrameRate);
}

- (void)autoTorch {
    
    AVCaptureDeviceInput* input = [self currentInput];
    
    if ([input.device isTorchAvailable] == NO)
        return;
    
    if ([input.device isTorchActive] == NO)
        return;
    
    [input.device lockForConfiguration:nil];
    if ([input.device isTorchModeSupported:AVCaptureTorchModeAuto]) {
        [input.device setTorchMode:AVCaptureTorchModeAuto];
    }
    [input.device unlockForConfiguration];
}

- (AVCaptureSession *)initSession {
    
    if (_session)
        return _session;
    
    self.videoOrientation = kKNVideoOrientationPortrait;
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = [self preset:_captureResolution];
    
    _devicePostion = AVCaptureDevicePositionFront;
    _cameraPosition = kKNCameraFront;

    AVCaptureDevice* device = [self cameraPosition:_devicePostion];
    
    NSError* error = nil;
    AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        NSLog(@"%s %@", __func__, [error localizedDescription]);
        return  [session autorelease];
        session = nil;
    }
    if ([session canAddInput:input])
        [session addInput:input];
    
    AVCaptureVideoDataOutput* output = [[AVCaptureVideoDataOutput alloc] init];
    output.alwaysDiscardsLateVideoFrames = YES;
    
    AVCaptureConnection* connection = [output connectionWithMediaType:AVMediaTypeVideo];
    connection.videoMinFrameDuration = CMTimeMake(1, _captureFrameRate);
    connection.videoMaxFrameDuration = CMTimeMake(1, 25);
    [self changeFrameRate:connection];
    
    int captureType = kCVPixelFormatType_32BGRA;
    if (_rawDataType == kKNRawDataYUV420Planar)
        captureType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;

    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:captureType]
                                                              forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    dispatch_queue_t captureQueue = dispatch_queue_create("catpureQueue", NULL);
    [output setSampleBufferDelegate:self queue:captureQueue];
    dispatch_release(captureQueue);

    [output setVideoSettings:videoSettings];
    
    
    dispatch_queue_t queue = dispatch_queue_create("captureQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    [session addOutput:output];
    
    if (_viewPreview) {
        AVCaptureVideoPreviewLayer* previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
        previewLayer.frame = _viewPreview.bounds;
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        [_viewPreview.layer addSublayer:previewLayer];
        
        self.previewLayer = previewLayer;
        [previewLayer release];
    }
    return  [session autorelease];
}

#pragma mark - Public
- (void)startVideoWithPreview:(UIView *)preview
                    frameRate:(NSInteger)frameRate
                   resolution:(KNCaptureResolution)resolution
                  captureType:(KNRawDataType)rawDataType
                    mirroring:(BOOL)mirror
                captureOutput:(void(^)(uint8_t* data, int len))captureOutBlock
                previewRender:(void(^)(uint8_t* data, int w, int h))previwBlock {

    self.viewPreview        = preview;
    self.captureFrameRate   = frameRate;
    self.captureResolution  = resolution;
    self.rawDataType        = rawDataType;
    _mirriring              = mirror;

    if (captureOutBlock)
        captureOutputBlock_ = [captureOutBlock copy];
    
    if (previwBlock)
        previewRenderBlock_ = [previwBlock copy];
    
    self.session = [self initSession];
    if (_session) {
        [_session startRunning];
    }
    
    [self setMirroring:_mirriring];
}

- (void)stopVideo {
    
    [self.session stopRunning];
    
    [self removeCurrentInput];
    [self removeCurrentOutput];
    
    
    [self.previewLayer removeFromSuperlayer];
    
    self.previewLayer = nil;
    self.session = nil;
}


- (void)previewVideoGravity:(KNPreviewGravity)gravity {
    
    NSString* g = AVLayerVideoGravityResize;
    switch (gravity) {
        case kKNGravityAspectFill:
            g = AVLayerVideoGravityResizeAspectFill;
            break;
            
        case kKNGravityAspectFit:
            g = AVLayerVideoGravityResizeAspect;
            break;
            
        default:
            g = AVLayerVideoGravityResize;
            break;
    }
    self.previewLayer.videoGravity = g;
}

- (void)changeCameraPosition:(KNCameraPosition)cameraPosition {
    
    AVCaptureDevicePosition pos = AVCaptureDevicePositionUnspecified;
    
    switch (cameraPosition) {
        case kKNCameraFront:
            pos = AVCaptureDevicePositionFront;
            break;
            
        case kKNCameraBack:
            pos = AVCaptureDevicePositionBack;
            break;
            
        case kKNCameraOff:
            pos = AVCaptureDevicePositionUnspecified;
            break;
            
        default:
            break;
    }
    _cameraPosition = cameraPosition;
    _devicePostion  = pos;
    
    [_session beginConfiguration];
    
    NSError* error = nil;
    AVCaptureDevice* device = [self cameraPosition:_devicePostion];
    AVCaptureDeviceInput* newInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!newInput) {
        NSLog(@"%s %@", __func__, [error localizedDescription]);
    } else {
        
        [self removeCurrentInput];
        if ([_session canAddInput:newInput]) {
            [_session addInput:newInput];
            
        }else {
            NSLog(@"%s : failed.", __func__);
        }
    }
    [_session commitConfiguration];
    
    
    if (_devicePostion == AVCaptureDevicePositionBack && _torchModeAuto) {
        [self autoTorch];
    }
}


- (BOOL)changeCaptureResolution:(KNCaptureResolution)resolution {
    
    NSString* preset = [self preset:resolution];
    
    if ([_session.sessionPreset isEqualToString:preset]) {
        NSLog(@"%s Same Preset.", __func__);
        return NO;
    }
    
    if ([_session canSetSessionPreset:preset]) {
        
        [_session beginConfiguration];
        
        NSError* error = nil;
        AVCaptureDevice* device = [self cameraPosition:_devicePostion];
        AVCaptureDeviceInput* newInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (!newInput) {
            NSLog(@"%s %@", __func__, [error localizedDescription]);
        } else {
            
            [self removeCurrentInput];
            if ([_session canAddInput:newInput]) {
                [_session addInput:newInput];
            }else
                NSLog(@"%s can addInput", __func__);
        }
        _session.sessionPreset = preset;
        
        [_session commitConfiguration];
        
        if (_devicePostion == AVCaptureDevicePositionBack && _torchModeAuto)
            [self autoTorch];
        
        return YES;
    }
    
    NSLog(@"%s doesn't support.[%@].", __func__, preset);
    return NO;
}

- (void)changeCaptureFrameRate:(NSInteger)framerate {
    
    if (_captureFrameRate == framerate)
        return;
    
    if (framerate > MAX_CAPTURE_FRAMERATE)
        framerate = MAX_CAPTURE_FRAMERATE;
    
    if (framerate <= 0)
        framerate = 1;
    
    _captureFrameRate = framerate;
}


- (void)totchToggle {
    
    AVCaptureDeviceInput* input = [self currentInput];
    
    if ([input.device isTorchAvailable] == NO)
        return;
    
    [input.device lockForConfiguration:nil];
    
    if ([input.device isTorchActive]) {
        
        if ([input.device isTorchModeSupported:AVCaptureTorchModeOff])
            [input.device setTorchMode:AVCaptureTorchModeOff];
    } else {
        
        if ([input.device isTorchModeSupported:AVCaptureTorchModeOn])
            [input.device setTorchMode:AVCaptureTorchModeOn];
        
    }
    [input.device unlockForConfiguration];
}

- (void)torchToggle {
    
    AVCaptureDeviceInput* input = [self currentInput];
    
    if ([input.device isTorchAvailable] == NO)
        return;
    
    [input.device lockForConfiguration:nil];
    
    if ([input.device isTorchActive]) {
        
        if ([input.device isTorchModeSupported:AVCaptureTorchModeOff])
            [input.device setTorchMode:AVCaptureTorchModeOff];
    } else {
        
        if ([input.device isTorchModeSupported:AVCaptureTorchModeOn])
            [input.device setTorchMode:AVCaptureTorchModeOn];
        
    }
    [input.device unlockForConfiguration];
}

- (void)setAutoTorchMode:(BOOL)use {
    _torchModeAuto = use;
}
- (void)setTorchLevel:(float)level {
    
}

- (BOOL)isMirroring {
    return  _mirriring;
}

- (void)setMirroring:(BOOL)mirror {
    
    if (_mirriring) {
        self.previewLayer.transform = CATransform3DMakeRotation(M_PI, 0.0f, 0.0f, 0.0f);
    } else {
        self.previewLayer.transform = CATransform3DMakeRotation(M_PI, 0.0f, 1.0f, 0.0f);
    }
    _mirriring = !_mirriring;
}

- (CGImageRef)imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef newContext = CGBitmapContextCreate(baseAddress,
                                                    width,
                                                    height,
                                                    8,
                                                    bytesPerRow,
                                                    colorSpace,
                                                    kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    CGContextRelease(newContext);
    
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    return newImage;
}



#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    
    void(^outputBlock)(uint8_t *yuv420p, int len, int w, int h) = ^(uint8_t *yuv420p, int len, int w, int h) {
        if (captureOutputBlock_) {
            
            if (previewRenderBlock_)
                previewRenderBlock_(yuv420p, w, h);
            captureOutputBlock_(yuv420p, len, w, h);
        }
    };

    
    if (_rawDataType == kKNRawDataRGB32) {
        [self rgbToYuv420:sampleBuffer completion:^(uint8_t *yuv420p, int len, int w, int h) {
            outputBlock(yuv420p, len, w, h);
        }];

    } else {
        
        [self yuv420PlanarToYuv420:sampleBuffer completion:^(uint8_t *yuv420p, int len, int w, int h) {
            outputBlock(yuv420p, len, w, h);
        }];
    }
    
    [self changeFrameRate:connection];
}


- (void)rgbToYuv420:(CMSampleBufferRef)sampleBuffer completion:(void(^)(uint8_t* yuv420p, int len, int w, int h))completion {
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    void* rgbSrc = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t len = CVPixelBufferGetDataSize(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
//    int width2 = width <= 352 ? 320 : width;
//    int height2 = height <= 288 ? 240 : height;

    
    
    float rate =  0.75;//height / (float)width;
    int w = height;
    int h = (int)(w * rate);
    if (h % 2 != 0)
        h -= 1;
        
    uint8_t* bufferI420 = [_imgConvert rgb32ToI420Rotate:rgbSrc size:len rotate:kKnImageRotate90];
//    uint8_t* scaleBuffer = [_imgConvert I420Scale:bufferI420 srcW:w srcH:h dstW:width2 dstH:height2 roatated:YES];

    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    if (completion)
        completion(bufferI420, (width * height * 3) >> 1, width, height);
}


- (void)yuv420PlanarToYuv420:(CMSampleBufferRef)sampleBuffer completion:(void(^)(uint8_t* yuv420p, int len, int w, int h))completion {

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    //    size_t len = CVPixelBufferGetDataSize(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    uint8_t *yPlaneAddress  = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);
    UInt32 yPixelCount      =  CVPixelBufferGetWidthOfPlane(imageBuffer,0);
    
    uint8_t *uvPlaneAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,1);
    UInt32 uvPixelCount     = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
    
//    KNImageRotate rotete = kKnImageRotate90;
//    BOOL iPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
//    if (iPad) {
//        rotete = kKnImageRotate180;
//        if (self.cameraPosition == kKNCameraBack) {
//            rotete = kKnImageRotate0;
//        }
//    }
    
    KNImageRotate rotete = kKnImageRotate90;
    if (_videoOrientation == kKNVideoOrientationLandscape) {
        rotete = kKnImageRotate180;
        if (self.cameraPosition == kKNCameraBack) {
            rotete = kKnImageRotate0;
        }
    }

    uint8_t* yuvBuffer = [_imgConvert YUV420PlaneToI420:yPlaneAddress yPixelCount:yPixelCount
                                               uvBuffer:uvPlaneAddress uvPixelCount:uvPixelCount
                                                 rotate:rotete];
    
//    uint8_t* scaleBuffer = [_imgConvert I420Scale:yuvBuffer srcW:width srcH:height dstW:width2 dstH:height2 roatated:!iPad];
    //    uint8_t* mirrorBuffer = [_imgConvert I420Mirror:scaleBuffer w:320 h:240];
    
    //    if (completion)
    //        completion(scaleBuffer, (width2 * height2 * 3) >> 1, width2, height2);
    
    if (completion) {
        
        if (_videoOrientation == kKNVideoOrientationPortrait) {
            int tmp = width;
            width = height;
            height = tmp;
        }
        completion(yuvBuffer, (width * height * 3) >> 1, width, height);
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}

- (void)rotateBuffer:(CMSampleBufferRef)sampleBuffer completion:(void(^)(uint8_t* data, int len, int w, int h))completion {
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    size_t bytesPerRow      = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width            = CVPixelBufferGetWidth(imageBuffer);
    size_t height           = CVPixelBufferGetHeight(imageBuffer);
    size_t currSize         = bytesPerRow * height * sizeof(unsigned char);
    size_t bytesPerRowOut   = 2 * height * sizeof(unsigned char);
    
    void *srcBuff = CVPixelBufferGetBaseAddress(imageBuffer);
    
    /*
     * rotationConstant:   0 -- rotate 0 degrees (simply copy the data from src to dest)
     *             1 -- rotate 90 degrees counterclockwise
     *             2 -- rotate 180 degress
     *             3 -- rotate 270 degrees counterclockwise
     */
    uint8_t rotationConstant = 0;
    
    unsigned char *outBuff = (unsigned char*)malloc(currSize);
    
    vImage_Buffer ibuff = { srcBuff, height, width, bytesPerRow};
    vImage_Buffer ubuff = { outBuff, width, height, bytesPerRowOut};
    
    Pixel_8888 bgColor = {0, 0, 0, 0};
    vImage_Error err= vImageRotate90_ARGB8888(&ibuff, &ubuff, rotationConstant, bgColor, 0);
    if (err != kvImageNoError) {
        NSLog(@"%ld", err);
        
        if (completion) {
            completion(NULL, 0, 0, 0);
        }
    }
    
    if (completion) {
        completion(outBuff, currSize, ubuff.width, ubuff.height);
    }
    free(outBuff);
}

@end
