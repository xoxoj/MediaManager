//
//  KNAudioManager.m
//  Aruts
//
//  Created by ken on 13. 5. 21..
//
//

#import "KNAudioManager.h"

static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData);

static OSStatus playbackCallback(void *inRefCon,
								 AudioUnitRenderActionFlags *ioActionFlags,
								 const AudioTimeStamp *inTimeStamp,
								 UInt32 inBusNumber,
								 UInt32 inNumberFrames,
								 AudioBufferList *ioData);

#define kOutputBus  0
#define kInputBus   1

KNAudioManager* gInstance = NULL;


@interface KNAudioManager () {
    void(^recDataBlock_)(uint8_t* pcmData, int size);
    void(^playDataBlock_)(uint8_t* playBuffer, int size);
}
@property (assign) AudioComponentInstance audioUnit;
@property (assign) float samplerate;

@property (retain, nonatomic) NSLock* recLock;
@property (retain, nonatomic) NSLock* playLock;

- (void)initAudio;
- (void)checkError:(int)ret key:(NSString *)key;
- (void)processAudio: (AudioBufferList*) bufferList;
@end

@implementation KNAudioManager

@synthesize audioUnit       = _audioUnit;
@synthesize samplerate      = _samplerate;
@synthesize recLock         = _recLock;
@synthesize playLock        = _playLock;


#pragma mark - Callback
static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    
    
	
	AudioBuffer buffer;
	
	buffer.mNumberChannels = 1;
	buffer.mDataByteSize = inNumberFrames * 2;
	buffer.mData = malloc( inNumberFrames * 2 );
	
	// Put buffer in a AudioBufferList
	AudioBufferList bufferList;
	bufferList.mNumberBuffers = 1;
	bufferList.mBuffers[0] = buffer;
	
    OSStatus status;
	
    status = AudioUnitRender([gInstance audioUnit],
                             ioActionFlags,
                             inTimeStamp,
                             inBusNumber,
                             inNumberFrames,
                             &bufferList);
    [gInstance checkError:status key:@"AudioUnitRender"];
	
    [gInstance.recLock lock];
    [gInstance processAudio:&bufferList];
    [gInstance.recLock unlock];
	
	// release the malloc'ed data in the buffer we created earlier
	free(bufferList.mBuffers[0].mData);

    return noErr;
}

static OSStatus playbackCallback(void *inRefCon,
								 AudioUnitRenderActionFlags *ioActionFlags,
								 const AudioTimeStamp *inTimeStamp,
								 UInt32 inBusNumber,
								 UInt32 inNumberFrames,
								 AudioBufferList *ioData) {
    

    [gInstance.playLock lock];
    memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);
    if (gInstance->playDataBlock_) {
        gInstance->playDataBlock_(ioData->mBuffers[0].mData, ioData->mBuffers[0].mDataByteSize);
    }
    [gInstance.playLock unlock];

    return noErr;
}



#pragma mark - View Cycle
- (void)dealloc {
    [_recLock release];
    [_playLock release];
    [super dealloc];
}

- (id)initWithSamplerate:(float)samplerate {
    self = [super init];
    if (self) {
        gInstance = self;
        _samplerate = samplerate;
        
        _recLock  = [[NSLock alloc] init];
        _playLock = [[NSLock alloc] init];
        
        [self initAudio];
    }
    return self;
}

#pragma mark - Private
- (void)checkError:(int)ret key:(NSString *)key {
    
    if (ret) {
        NSLog(@"@KNAudioManager Error : %@(%d)", key, ret);
    }
}

- (void)processAudio: (AudioBufferList*) bufferList {    
    if (recDataBlock_) {
        recDataBlock_(bufferList->mBuffers[0].mData, bufferList->mBuffers[0].mDataByteSize);
    }
}

- (void)initAudio {
    
    OSStatus status;
	
	// Describe audio component
	AudioComponentDescription desc;
	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_RemoteIO;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	
	// Get component
	AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
	
	// Get audio units
	status = AudioComponentInstanceNew(inputComponent, &_audioUnit);
	[self checkError:status key:@"AudioComponentInstanceNew"];
	
	// Enable IO for recording
	UInt32 flag = 1;
	status = AudioUnitSetProperty(_audioUnit,
								  kAudioOutputUnitProperty_EnableIO,
								  kAudioUnitScope_Input,
								  kInputBus,
								  &flag,
								  sizeof(flag));
	[self checkError:status key:@"kAudioOutputUnitProperty_EnableIO"];
	
	// Enable IO for playback
	status = AudioUnitSetProperty(_audioUnit,
								  kAudioOutputUnitProperty_EnableIO,
								  kAudioUnitScope_Output,
								  kOutputBus,
								  &flag,
								  sizeof(flag));
	[self checkError:status key:@"kAudioOutputUnitProperty_EnableIO"];
    
	// Describe format
	AudioStreamBasicDescription audioFormat;
	audioFormat.mSampleRate			= _samplerate;
	audioFormat.mFormatID			= kAudioFormatLinearPCM;
	audioFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	audioFormat.mFramesPerPacket	= 1;
	audioFormat.mChannelsPerFrame	= 1;
	audioFormat.mBitsPerChannel		= 16;
	audioFormat.mBytesPerPacket		= 2;
	audioFormat.mBytesPerFrame		= 2;
	
	// Apply format
	status = AudioUnitSetProperty(_audioUnit,
								  kAudioUnitProperty_StreamFormat,
								  kAudioUnitScope_Output,
								  kInputBus,
								  &audioFormat,
								  sizeof(audioFormat));
    [self checkError:status key:@"kAudioUnitProperty_StreamFormat"];
    
	status = AudioUnitSetProperty(_audioUnit,
								  kAudioUnitProperty_StreamFormat,
								  kAudioUnitScope_Input,
								  kOutputBus,
								  &audioFormat,
								  sizeof(audioFormat));
    [self checkError:status key:@"kAudioUnitProperty_StreamFormat"];
	
	
	// Set input callback
	AURenderCallbackStruct callbackStruct;
	callbackStruct.inputProc = recordingCallback;
	callbackStruct.inputProcRefCon = self;
	status = AudioUnitSetProperty(_audioUnit,
								  kAudioOutputUnitProperty_SetInputCallback,
								  kAudioUnitScope_Global,
								  kInputBus,
								  &callbackStruct,
								  sizeof(callbackStruct));
    [self checkError:status key:@"kAudioOutputUnitProperty_SetInputCallback"];
	
	// Set output callback
	callbackStruct.inputProc = playbackCallback;
	callbackStruct.inputProcRefCon = self;
	status = AudioUnitSetProperty(_audioUnit,
								  kAudioUnitProperty_SetRenderCallback,
								  kAudioUnitScope_Global,
								  kOutputBus,
								  &callbackStruct,
								  sizeof(callbackStruct));
	[self checkError:status key:@"kAudioUnitProperty_SetRenderCallback"];
	
	// Disable buffer allocation for the recorder (optional - do this if we want to pass in our own)
	flag = 0;
	status = AudioUnitSetProperty(_audioUnit,
								  kAudioUnitProperty_ShouldAllocateBuffer,
								  kAudioUnitScope_Output,
								  kInputBus,
								  &flag,
								  sizeof(flag));
	   
    Float32 preferredBufferSize = 0.01; // in seconds
    status = AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration,
                                     sizeof(preferredBufferSize),
                                     &preferredBufferSize);
    
    AudioSessionSetActive(true);
    
	// Initialise
	status = AudioUnitInitialize(_audioUnit);
	[self checkError:status key:@"AudioUnitInitialize"];
}


#pragma mark - Public
- (void)startRecording:(void(^)(uint8_t* pcmData, int size))dataBlock {

    if (recDataBlock_) {
        [recDataBlock_ release];
    }
    recDataBlock_ = [dataBlock copy];
    
	OSStatus status = AudioOutputUnitStart(_audioUnit);
    [self checkError:status key:@"AudioOutputUnitStart"];
}

- (void)stopRecording {
    
    if (recDataBlock_) {
        [recDataBlock_ release];
        recDataBlock_ = nil;
    }

    [self setPlayBlock:nil];
 	OSStatus status = AudioOutputUnitStop(_audioUnit);
    [self checkError:status key:@"AudioOutputUnitStop"];
    
    AudioUnitUninitialize(_audioUnit);
}

- (void)setPlayBlock:(void(^)(uint8_t* playBuffer, int size))playBlock {
    
    if (playBlock == nil) {
        if (playDataBlock_) {
            [playDataBlock_ release];
        }
        playDataBlock_ = nil;
        return;
    }
    
    if (playDataBlock_) {
        [playDataBlock_ release];
    }
    playDataBlock_ = [playBlock copy];
}

- (void)setSpeakerPhone:(BOOL)speakerPhone {
}

@end
