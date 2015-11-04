#import "FrameMovieExporter.h"

@implementation FrameMovieExporter

- (id) initWithCodec:(CodecType)codec pixelsWide:(unsigned)width pixelsHigh:(unsigned)height options:(ICMCompressionSessionOptionsRef)options
{
	//Make sure client goes through designated initializer
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (id) initWithPath:(NSString*)path codec:(CodecType)codec pixelsWide:(unsigned)width pixelsHigh:(unsigned)height options:(ICMCompressionSessionOptionsRef)options
{
	//ICMCompressionSessionOptionsRef	options = [[self class] defaultOptions];
	Boolean							boolean = true;
	OSErr							theError;
	Handle							dataRef;
	OSType							dataRefType;
	
	//Check parameters
	if(![path length]) {
		[self release];
		return nil;
	}
	
	//Customize compression options - We must enable P & B frames explicitely
	/*
	ICMCompressionSessionOptionsSetAllowTemporalCompression(options, true);
	ICMCompressionSessionOptionsSetAllowFrameReordering(options, true);
	ICMCompressionSessionOptionsSetAllowFrameTimeChanges(options, true);
	ICMCompressionSessionOptionsSetDurationsNeeded(options, true);
	ICMCompressionSessionOptionsSetProperty(options, kQTPropertyClass_ICMCompressionSessionOptions, kICMCompressionSessionOptionsPropertyID_Quality, sizeof(CodecQ), &quality);
	*/
	//ICMCompressionSessionOptionsCreateCopy(kCFAllocatorDefault, options, &options);
	ICMCompressionSessionOptionsSetProperty(options, kQTPropertyClass_ICMCompressionSessionOptions, kICMCompressionSessionOptionsPropertyID_AllowAsyncCompletion, sizeof(Boolean), &boolean);
	//[(id)options autorelease];
	
	//Initialize super class
	if(self = [super initWithCodec:codec pixelsWide:width pixelsHigh:height options:options]) {
		//Create movie file
		theError = QTNewDataReferenceFromFullPathCFString((CFStringRef)path, kQTNativeDefaultPathStyle, 0, &dataRef, &dataRefType);
		if(theError) {
			NSLog(@"QTNewDataReferenceFromFullPathCFString() failed with error %i", theError);
			[self release];
			return nil;
		}
		theError = CreateMovieStorage(dataRef, dataRefType, 'TVOD', smCurrentScript, createMovieFileDeleteCurFile, &_dataHandler, &_movie);
		if(theError) {
			NSLog(@"CreateMovieStorage() failed with error %i", theError);
			[self release];
			return nil;
		}
		
		//Add track
		_track = NewMovieTrack(_movie, width << 16, height << 16, 0);
		theError = GetMoviesError();
		if(theError) {
			NSLog(@"NewMovieTrack() failed with error %i", theError);
			[self release];
			return nil;
		}
		
		//Create track media
		_media = NewTrackMedia(_track, VideoMediaType, ICMCompressionSessionGetTimeScale(_compressionSession), 0, 0);
		theError = GetMoviesError();
		if(theError) {
			NSLog(@"NewTrackMedia() failed with error %i", theError);
			[self release];
			return nil;
		}
		
		//Prepare media for editing
		theError = BeginMediaEdits(_media);
		if(theError) {
			NSLog(@"BeginMediaEdits() failed with error %i", theError);
			[self release];
			return nil;
		}
	}
	
	return self; 
}

- (void) dealloc
{
	OSErr							theError;
	
	if(_media) {
		//Make sure all frames have been processed by the compressor
		[self flushFrames];
		
		//End media editing
		theError = EndMediaEdits(_media);
		if(theError)
		NSLog(@"EndMediaEdits() failed with error %i", theError);
		theError = ExtendMediaDecodeDurationToDisplayEndTime(_media, NULL);
		if(theError)
		NSLog(@"ExtendMediaDecodeDurationToDisplayEndTime() failed with error %i", theError);
		
		//Add media to track
		theError = InsertMediaIntoTrack(_track, 0, 0, GetMediaDisplayDuration(_media), fixed1);
		if(theError)
		NSLog(@"InsertMediaIntoTrack() failed with error %i", theError);
		
		//Write movie
		theError = AddMovieToStorage(_movie, _dataHandler);
		if(theError)
		NSLog(@"AddMovieToStorage() failed with error %i", theError);
	}
	
	//Close movie file
	if(_dataHandler)
	CloseMovieStorage(_dataHandler);
	if(_movie)
	DisposeMovie(_movie);
	
	[super dealloc];
}

- (void) doneCompressingFrame:(ICMEncodedFrameRef)frame
{
	OSErr							theError;
	
	//Add frame to track media - Ignore the last frame which will have a duration of 0
	if(ICMEncodedFrameGetDecodeDuration(frame) > 0) {
		theError = AddMediaSampleFromEncodedFrame(_media, frame, NULL);
		if(theError)
		NSLog(@"AddMediaSampleFromEncodedFrame() failed with error %i", theError);
	}
	
	[super doneCompressingFrame:frame];
}

- (BOOL) exportFrame:(CVPixelBufferRef)frame timeStamp:(NSTimeInterval)timestamp
{
	return [super compressFrame:frame timeStamp:timestamp duration:NAN];
}

@end
