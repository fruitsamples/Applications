#import <OpenGL/CGLMacro.h>

#import "FrameCompressor.h"

#define kTimeScale 1000000

static OSStatus _FrameOutputCallback(void* encodedFrameOutputRefCon, ICMCompressionSessionRef session, OSStatus error, ICMEncodedFrameRef frame, void* reserved)
{
	//Simply forward to the FrameCompressor instance
	if(error == noErr)
	[(FrameCompressor*)encodedFrameOutputRefCon doneCompressingFrame:frame];
	
	return error;
}

@implementation FrameCompressor

+ (void) initialize
{
	//Make sure QuickTime is initialized
	EnterMovies();
}

+ (id) alloc
{
	//Prevent direct allocation of this abstract class
	if(self == [FrameCompressor class])
	[self doesNotRecognizeSelector:_cmd];
	
	return [super alloc];
}

+ (ICMCompressionSessionOptionsRef) defaultOptions
{
	ICMCompressionSessionOptionsRef			options;
	OSStatus								theError;
	
	//Create compression session options
	theError = ICMCompressionSessionOptionsCreate(kCFAllocatorDefault, &options);
	if(theError) {
		NSLog(@"ICMCompressionSessionCreate() failed with error %i", theError);
		return NULL;
	}
	
	return (ICMCompressionSessionOptionsRef)[(id)options autorelease];
}

+ (ICMCompressionSessionOptionsRef) userOptions:(CodecType*)outCodecType frameRate:(double*)outFrameRate autosaveName:(NSString*)name
{
	long									flags = scAllowEncodingWithCompressionSession;
	ICMMultiPassStorageRef					nullStorage = NULL;
	SCTemporalSettings						temporalSettings;
	SCSpatialSettings						spatialSettings;
	ComponentResult							theError;
	ICMCompressionSessionOptionsRef			options;
	ComponentInstance						component;
	QTAtomContainer							container;
	NSData*									data;
	
	//Open default compression dialog component
	component = OpenDefaultComponent(StandardCompressionType, StandardCompressionSubType);
	if(component == NULL) {
		NSLog(@"Compression component opening failed");
		return NULL;
	}
	SCSetInfo(component, scPreferenceFlagsType, &flags);
	
	//Restore compression settings from user defaults
	if([name length]) {
		data = [[NSUserDefaults standardUserDefaults] objectForKey:name];
		if(data) {
			container = NewHandle([data length]);
			if(container) {
				[data getBytes:*container];
				theError = SCSetSettingsFromAtomContainer(component, container);
				if(theError)
				NSLog(@"SCSetSettingsFromAtomContainer() failed with error %i", theError);
				QTDisposeAtomContainer(container);
			}
		}
	}
	
	//Display compression dialog to user
	theError = SCRequestSequenceSettings(component);
	if(theError) {
		if(theError != 1)
		NSLog(@"SCRequestSequenceSettings() failed with error %i", theError);
		CloseComponent(component);
		return NULL;
	}
	
	//Save compression settings in user defaults
	if([name length]) {
		theError = SCGetSettingsAsAtomContainer(component, &container);
		if(theError)
		NSLog(@"SCSetSettingsFromAtomContainer() failed with error %i", theError);
		else {
			data = [NSData dataWithBytes:*container length:GetHandleSize(container)];
			[[NSUserDefaults standardUserDefaults] setObject:data forKey:name];
			QTDisposeAtomContainer(container);
		}
	}
	
	//Copy settings from compression dialog
	theError = SCCopyCompressionSessionOptions(component, &options);
	if(theError) {
		NSLog(@"SCCopyCompressionSessionOptions() failed with error %i", theError);
		CloseComponent(component);
		return NULL;
	}
	if(outCodecType) {
		SCGetInfo(component, scSpatialSettingsType, &spatialSettings);
		*outCodecType = spatialSettings.codecType;
	}
	if(outFrameRate) {
		SCGetInfo(component, scTemporalSettingsType, &temporalSettings);
		*outFrameRate = Fix2X(temporalSettings.frameRate);
	}
	CloseComponent(component);
	
	//Explicitely turn off multipass compression in case it was enabled by the user as we do not support it
	ICMCompressionSessionOptionsSetProperty(options, kQTPropertyClass_ICMCompressionSessionOptions, kICMCompressionSessionOptionsPropertyID_MultiPassStorage, sizeof(ICMMultiPassStorageRef), &nullStorage);
	
	return (ICMCompressionSessionOptionsRef)[(id)options autorelease];
}

- (id) init
{
	//Make sure client goes through designated initializer
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (id) initWithCodec:(CodecType)codec pixelsWide:(unsigned)width pixelsHigh:(unsigned)height options:(ICMCompressionSessionOptionsRef)options
{
	ICMEncodedFrameOutputRecord				record = {_FrameOutputCallback, self, NULL};
	OSStatus								theError;
	
	//Check parameters
	if((codec == 0) || (width == 0) || (height == 0) || (options == NULL)) {
		[self release];
		return nil;
	}
	
	if(self = [super init]) {
		//Create compression session
		theError = ICMCompressionSessionCreate(kCFAllocatorDefault, width, height, codec, kTimeScale, options, NULL, &record, &_compressionSession);
		if(theError) {
			NSLog(@"ICMCompressionSessionCreate() failed with error %i", theError);
			[self release];
			return nil;
		}
	}
	
	return self;
}

- (void) dealloc
{
	//Release resources
	if(_compressionSession)
	ICMCompressionSessionRelease(_compressionSession);
	
	[super dealloc];
}

- (BOOL) compressFrame:(CVPixelBufferRef)frame timeStamp:(NSTimeInterval)timestamp duration:(NSTimeInterval)duration
{
	OSStatus								theError;
	
	//Pass frame to compression session
	theError = ICMCompressionSessionEncodeFrame(_compressionSession, frame, (timestamp >= 0.0 ? (SInt64)(timestamp * kTimeScale) : 0), (duration >= 0.0 ? (SInt64)(duration * kTimeScale) : 0), ((timestamp >= 0.0 ? kICMValidTime_DisplayTimeStampIsValid : 0) | (duration >= 0.0 ? kICMValidTime_DisplayDurationIsValid : 0)), NULL, NULL, NULL);
	if(theError)
	NSLog(@"ICMCompressionSessionEncodeFrame() failed with error %i", theError);
	
	return (theError == noErr ? YES : NO);
}

- (BOOL) flushFrames
{
	OSStatus								theError;
	
	//Flush pending frames in compression session
	theError = ICMCompressionSessionCompleteFrames(_compressionSession, true, 0, 0);
	if(theError)
	NSLog(@"ICMCompressionSessionCompleteFrames() failed with error %i", theError);
	
	return (theError == noErr ? YES : NO);
}

- (void) doneCompressingFrame:(ICMEncodedFrameRef)frame
{
	//Do nothing
}

@end
