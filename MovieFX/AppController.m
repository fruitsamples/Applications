#import "AppController.h"

/* Preview rendering frame rate */
#define kPreviewFPS 30.0

static OSStatus _FrameOutputCallback(void* encodedFrameOutputRefCon, ICMCompressionSessionRef session, OSStatus error, ICMEncodedFrameRef frame, void* reserved)
{
	/* Simply add the encoded frame to the track's media */
	if(error == noErr) {
		if(ICMEncodedFrameGetDecodeDuration(frame) > 0)
		error = AddMediaSampleFromEncodedFrame((Media)encodedFrameOutputRefCon, frame, NULL);
	}
	
	return error;
}

@implementation ImageView

- (NSDragOperation) draggingEntered:(id<NSDraggingInfo>)sender
{
	NSPasteboard*			pboard = [sender draggingPasteboard];
	NSArray*				files;
	NSString*				extension;
	
	//Check if the dragging pasteboard contains a single movie file
	if([pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]) {
		files = [pboard propertyListForType:NSFilenamesPboardType];
		if([files count] == 1) {
			extension = [[[files objectAtIndex:0] pathExtension] lowercaseString];
			if([extension isEqualToString:@"mov"])
			return NSDragOperationCopy;
		}
	}
	
	return NSDragOperationNone;
}

- (void) draggingExited:(id<NSDraggingInfo>)sender
{
	//Do nothing
}

- (BOOL) prepareForDragOperation:(id<NSDraggingInfo>)sender
{
	//Do nothing
	return YES;
}

- (BOOL) performDragOperation:(id<NSDraggingInfo>)sender
{
	NSPasteboard*			pboard = [sender draggingPasteboard];
	NSString*				path;
	
	//Clear image
	[self setImage:nil];
	
	//Load the movie file by passing its path to the AppController and update our image to reflect the file's icon
	if([pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]) {
		path = [[pboard propertyListForType:NSFilenamesPboardType] objectAtIndex:0];
		if(![(AppController*)[NSApp delegate] loadMovie:path])
		return NO;
		[self setImage:[[NSWorkspace sharedWorkspace] iconForFile:path]];
		return YES;
	}
	
	return NO;
}

- (void) concludeDragOperation:(id<NSDraggingInfo>)sender
{
	//Do nothing
}

@end

@implementation AppController

- (void) _previewTimer:(NSTimer*)timer
{
	CVImageBufferRef				imageBuffer;
	NSTimeInterval					time;
	TimeRecord						movieTime;
	
	/* If we have a movie loaded, check if a new frame is available, potentially process it,
		then display it using the composition loaded on the QCView which has an "image" input */
	if(_movie) {
		MoviesTask(_movie, 0);
		QTVisualContextTask(_visualContext);
		if(QTVisualContextIsNewImageAvailable(_visualContext, NULL) && (QTVisualContextCopyImageForTime(_visualContext, kCFAllocatorDefault, NULL, &imageBuffer) == noErr)) {
			if(_renderer) {
				/* Get current movie time */
				GetMovieTime(_movie, &movieTime);
				time = (NSTimeInterval)*((SInt64*)&movieTime.value) / (NSTimeInterval)movieTime.scale;
				
				/* Process movie frame with QCRenderer */
				[_renderer setValue:(id)imageBuffer forInputKey:QCCompositionInputImageKey];
				if(![_renderer renderAtTime:time arguments:nil])
				NSLog(@"QCRenderer rendering failed at time %fs", time);
				
				/* Retrieve the processed frame from the QCRenderer and pass it to the QCView for display
					Because we pass the image from one Quartz Composer object to another one, we can use the optimized QCImage type. */
				[qcView setValue:[_renderer valueForOutputKey:QCCompositionOutputImageKey ofType:@"QCImage"] forInputKey:@"image"];
			}
			else {
				/* Since there is no QCRenderer around, display the movie frame directly on the QCView */
				[qcView setValue:(id)imageBuffer forInputKey:@"image"];
			}
			
			/* Replace the default image used by the composition picker with the movie frame */
			[pickerView setDefaultValue:(id)imageBuffer forInputKey:QCCompositionInputImageKey];
			
			CVBufferRelease(imageBuffer);
		}
	}
}

- (void) applicationDidFinishLaunching:(NSNotification*)notification
{
	/* Create the QuickTime visual context to play the movie on and make sure it uses the same OpenGL context and pixel format as the QCView */
	if(QTOpenGLTextureContextCreate(kCFAllocatorDefault, [[qcView openGLContext] CGLContextObj], [[qcView openGLPixelFormat] CGLPixelFormatObj], NULL, &_visualContext) != noErr) {
		NSLog(@"Cannot create QuickTime visual context");
		[NSApp terminate:nil];
	}
	
	/* Load the composition on the QCView */
	if(![qcView loadCompositionFromFile:[[NSBundle mainBundle] pathForResource:@"Composition" ofType:@"qtz"]] || ![qcView startRendering]) {
		NSLog(@"Cannot run composition");
		[NSApp terminate:nil];
	}
	
	/* Configure the user interface */
	[progressIndicator setUsesThreadedAnimation:YES];
	[pickerView setShowsCompositionNames:YES];
	[pickerView setAllowsEmptySelection:YES];
	[pickerView setCompositionsFromRepositoryWithProtocol:QCCompositionProtocolImageFilter andAttributes:nil];
	[pickerView setDrawsBackground:NO];
	[parameterView setDrawsBackground:NO];
	
	/* Set up the preview timer */
	_timer = [[NSTimer timerWithTimeInterval:(1.0 / kPreviewFPS) target:self selector:@selector(_previewTimer:) userInfo:nil repeats:YES] retain];
	[[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSEventTrackingRunLoopMode];
	
	/* Show window */
	[window makeKeyAndOrderFront:nil];
}

- (void) applicationWillTerminate:(NSNotification*)notification
{
	/* Destroy preview timer */
	if(_timer) {
		[_timer invalidate];
		[_timer release];
	}
	
	/* Clean up */
	if(_renderer)
	[_renderer release];
	if(_movie) {
		StopMovie(_movie);
		DisposeMovie(_movie);
	}
	if(_visualContext)
	QTVisualContextRelease(_visualContext);
}

- (void) compositionPickerView:(QCCompositionPickerView*)pickerView didSelectComposition:(QCComposition*)composition
{
	CGColorSpaceRef					colorSpace;
	
	/* Create a processing-only QCRenderer that wraps the selected composition if any - We use the main display colorspace as we render on screen */
	[_renderer release];
	if(composition) {
		colorSpace = CGDisplayCopyColorSpace(kCGDirectMainDisplay);
		_renderer = [[QCRenderer alloc] initWithComposition:composition colorSpace:colorSpace];
		CGColorSpaceRelease(colorSpace);
		if(_renderer == nil) {
			NSLog(@"Cannot create QCRenderer");
			[NSApp terminate:nil];
		}
	}
	else
	_renderer = nil;
	
	/* Make sure the QCCompositionParameterView targets the QCRenderer */
	[parameterView setCompositionRenderer:_renderer];
	
	/* Reset user interface */
	[qcView setValue:nil forInputKey:@"image"];
	[exportButton setEnabled:(_movie && composition ? YES : NO)];
}

- (BOOL) compositionParameterView:(QCCompositionParameterView*)parameterView shouldDisplayParameterWithKey:(NSString*)portKey attributes:(NSDictionary*)portAttributes
{
	/* Make sure the input image parameter is not visible as we are setting it directly */
	return ![portKey isEqualToString:QCCompositionInputImageKey];
}

- (void) windowWillClose:(NSNotification*)notification
{
	[NSApp terminate:self];
}

- (BOOL) loadMovie:(NSString*)path
{
	Boolean							active = true;
	QTNewMoviePropertyElement		properties[] = {
														{kQTPropertyClass_DataLocation, kQTDataLocationPropertyID_CFStringNativePath, sizeof(CFStringRef), &path, 0},
														{kQTPropertyClass_NewMovieProperty, kQTNewMoviePropertyID_Active, sizeof(Boolean), &active, 0},
														{kQTPropertyClass_Context, kQTContextPropertyID_VisualContext, sizeof(QTVisualContextRef), &_visualContext, 0}
													};
	OSErr							error;
	Rect							bounds;
	
	/* Reset user interface */
	[pickerView setDefaultValue:nil forInputKey:QCCompositionInputImageKey];
	[qcView setValue:nil forInputKey:@"image"];
	
	/* Destroy currently loaded movie if any */
	if(_movie) {
		StopMovie(_movie);
		DisposeMovie(_movie);
	}
	
	/* Load new movie, prepare it then starts playback */
	if(NewMovieFromProperties(sizeof(properties) / sizeof(QTNewMoviePropertyElement), properties, 0, NULL, &_movie) != noErr)
	_movie = NULL;
	if(_movie) {
		SetMoviePlayHints(_movie, hintsHighQuality | hintsDeinterlaceFields, hintsHighQuality | hintsDeinterlaceFields);
		SetTimeBaseFlags(GetMovieTimeBase(_movie), loopTimeBase);
		GoToBeginningOfMovie(_movie);
		StartMovie(_movie);
		
		if(error = GetMoviesError()) {
			NSLog(@"QuickTime error %i", error);
			StopMovie(_movie);
			DisposeMovie(_movie);
			_movie = NULL;
		}
		else {
			GetMovieBox(_movie, &bounds);
			[pickerView setCompositionAspectRatio:NSMakeSize(bounds.right, bounds.bottom)];
		}
	}
	
	/* Update user interface */
	[exportButton setEnabled:(_movie && [pickerView selectedComposition] ? YES : NO)];
	
	return (_movie ? YES : NO);
}

- (ICMCompressionSessionOptionsRef) getCompressionOptionsAndCodec:(CodecType*)outCodecType frameRate:(double*)outFrameRate usingAutosaveName:(NSString*)name
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
	
	/* Open default compression dialog component */
	component = OpenDefaultComponent(StandardCompressionType, StandardCompressionSubType);
	if(component == NULL) {
		NSLog(@"Compression component opening failed");
		return NULL;
	}
	SCSetInfo(component, scPreferenceFlagsType, &flags);
	
	/* Restore compression settings from user defaults */
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
	
	/* Display compression dialog to user */
	theError = SCRequestSequenceSettings(component);
	if(theError) {
		if(theError != 1)
		NSLog(@"SCRequestSequenceSettings() failed with error %i", theError);
		CloseComponent(component);
		return NULL;
	}
	
	/* Save compression settings in user defaults */
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
	
	/* Copy settings from compression dialog */
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
	
	return (ICMCompressionSessionOptionsRef)[(id)options autorelease];
}

- (IBAction) performExport:(id)sender
{
	BOOL							success = NO;
	NSSavePanel*					savePanel = [NSSavePanel savePanel];
	OSType							type = VisualMediaCharacteristic;
	Fixed							zeroFixed = 0;
	QCRenderer*						renderer = nil;
	Movie							outMovie = NULL;
	ICMMultiPassStorageRef			nullStorage = NULL;
	TimeScale						timeScale;
	Rect							bounds;
	CGColorSpaceRef					colorSpace;
	NSAutoreleasePool*				pool;
	CVImageBufferRef				imageBuffer;
	TimeValue						frameTime,
									frameDuration;
	NSTimeInterval					time;
	CVPixelBufferRef				pixelBuffer;
	ICMCompressionSessionOptionsRef	compressionOptions;
	OSStatus						error;
	Media							media;
	ICMEncodedFrameOutputRecord		outputRecord;
	Track							track;
	Handle							dataRef;
	OSType							dataRefType;
	DataHandler						dataHandler;
	ICMCompressionSessionRef		compressionSession;
	CodecType						codec;
	NSArray*						array;
	int								i;
	NSString*						key;
	
	/* Stop preview timer */
	if(_timer) {
		[_timer invalidate];
		[_timer release];
	}
	
	/* Stop movie playback and reset movie */
	StopMovie(_movie);
	GoToBeginningOfMovie(_movie);
	timeScale = GetMovieTimeScale(_movie);
	GetMovieBox(_movie, &bounds);
	
	/* Update user interface */
	[progressIndicator setIndeterminate:NO];
	[progressIndicator setMaxValue:(double)GetMovieDuration(_movie) / (double)timeScale];
	[progressIndicator setDoubleValue:0];
	[progressIndicator startAnimation:nil];
	
	/* Ask user for a location where to save the output movie */
	[savePanel setRequiredFileType:@"mov"];
	if([savePanel runModalForDirectory:nil file:@"Processed Movie"] != NSFileHandlingPanelOKButton)
	goto Cleanup;
	
	/* Create output movie and prepare video track */
	error = QTNewDataReferenceFromFullPathCFString((CFStringRef)[savePanel filename], kQTNativeDefaultPathStyle, 0, &dataRef, &dataRefType);
	if(error != noErr)
	goto Cleanup;
	error = CreateMovieStorage(dataRef, dataRefType, 'TVOD', smCurrentScript, createMovieFileDeleteCurFile, &dataHandler, &outMovie);
	if(error != noErr)
	goto Cleanup;
	track = NewMovieTrack(outMovie, bounds.right << 16, bounds.bottom << 16, 0);
	if(GetMoviesError() != noErr)
	goto Cleanup;
	media = NewTrackMedia(track, VideoMediaType, timeScale, 0, 0);
	if(GetMoviesError() != noErr)
	goto Cleanup;
	error = BeginMediaEdits(media);
	if(error != noErr)
	goto Cleanup;
	
	/* Get compression options from user and create compression session */
	compressionOptions = [self getCompressionOptionsAndCodec:&codec frameRate:NULL usingAutosaveName:@"compressionOptions"]; //FIXME: Should we do something with the specified framerate?
	if(compressionOptions == NULL)
	goto Cleanup;
	ICMCompressionSessionOptionsSetProperty(compressionOptions, kQTPropertyClass_ICMCompressionSessionOptions, kICMCompressionSessionOptionsPropertyID_MultiPassStorage, sizeof(ICMMultiPassStorageRef), &nullStorage); //Make sure multipasses compression is disabled
	ICMCompressionSessionOptionsSetProperty(compressionOptions, kQTPropertyClass_ICMCompressionSessionOptions, kICMCompressionSessionOptionsPropertyID_ExpectedFrameRate, sizeof(Fixed), &zeroFixed); //Make sure exprected framerate is not set as we ignore it 
	outputRecord.encodedFrameOutputCallback = _FrameOutputCallback;
	outputRecord.encodedFrameOutputRefCon = media;
	outputRecord.frameDataAllocator	= kCFAllocatorDefault;
	error = ICMCompressionSessionCreate(kCFAllocatorDefault, bounds.right, bounds.bottom, codec, timeScale, compressionOptions, NULL, &outputRecord, &compressionSession);
	if(error != noErr)
	goto Cleanup;
	
	/* Create a processing-only local QCRenderer with the selected composition and the proper output colorspace - FIXME: We should use a colorspace appropriate for video */
	colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	renderer = [[QCRenderer alloc] initWithComposition:[pickerView selectedComposition] colorSpace:colorSpace];
	CGColorSpaceRelease(colorSpace);
	if(renderer == nil)
	goto Cleanup;
	
	/* Copy input parameter values from global QCRenderer to local QCRenderer */
	array = [_renderer inputKeys];
	for(i = 0; i < [array count]; ++i) {
		key = [array objectAtIndex:i];
		if(![key isEqualToString:QCCompositionInputImageKey])
		[renderer setValue:[_renderer valueForInputKey:key] forInputKey:key];
	}
	
	/* Process movie frames */
	GetMovieNextInterestingTime(_movie, nextTimeMediaSample | nextTimeEdgeOK, 1, &type, 0, fixed1, &frameTime, &frameDuration);
	while(frameTime >= 0) {
		/* Create local autorelease pool */
		pool = [NSAutoreleasePool new];
		
		/* Extract next frame from movie */
		SetMovieTimeValue(_movie, frameTime);
		MoviesTask(_movie, 0);
		QTVisualContextTask(_visualContext);
		if(!QTVisualContextIsNewImageAvailable(_visualContext, NULL) || (QTVisualContextCopyImageForTime(_visualContext, kCFAllocatorDefault, NULL, &imageBuffer) != noErr)) {
			NSLog(@"Failed retrieving movie frame");
			goto Cleanup;
		}
		
		/* Update user interface */
		time = ((NSTimeInterval)frameTime / (NSTimeInterval)timeScale);
		[progressIndicator setDoubleValue:time];
		[progressIndicator display];
		
		/* Process frame with local QCRenderer and retrieved processed frame as a CVPixelBuffer to pass to compression session */
		[renderer setValue:(id)imageBuffer forInputKey:QCCompositionInputImageKey];
		if(![renderer renderAtTime:time arguments:nil]) {
			NSLog(@"Movie frame processing failed at tinme %fs", time);
			goto Cleanup;
		}
		pixelBuffer = (CVPixelBufferRef)[renderer valueForOutputKey:QCCompositionOutputImageKey ofType:@"CVPixelBuffer"];
		if(pixelBuffer == NULL) {
			NSLog(@"Failed retrieving processed movie frame");
			goto Cleanup;
		}
		
		/* Encode processed frame */
		error = ICMCompressionSessionEncodeFrame(compressionSession, pixelBuffer, frameTime, frameDuration, kICMValidTime_DisplayTimeStampIsValid | kICMValidTime_DisplayDurationIsValid, NULL, NULL, NULL);
		if(error != noErr) {
			NSLog(@"Failed encoding processed movie frame (%i)", error);
			goto Cleanup;
		}
		
		/* Clean up */
		CVBufferRelease(imageBuffer);
		[pool release];
		
		/* Get next movie frame */
		GetMovieNextInterestingTime(_movie, nextTimeMediaSample, 1, &type, frameTime, fixed1, &frameTime, &frameDuration);
	}
	
	success = YES;
	
Cleanup:
	
	/* Close output movie - FIXME: Do proper error handling */
	if(outMovie) {
		ICMCompressionSessionCompleteFrames(compressionSession, true, 0, 0);
		EndMediaEdits(media);
		ExtendMediaDecodeDurationToDisplayEndTime(media, NULL);
		InsertMediaIntoTrack(track, 0, 0, GetMediaDisplayDuration(media), fixed1);
		AddMovieToStorage(outMovie, dataHandler);
		CloseMovieStorage(dataHandler);
		DisposeMovie(outMovie);
		ICMCompressionSessionRelease(compressionSession);
	}
	
	/* Delete output movie file in case of failure */
	if(success == NO)
	[[NSFileManager defaultManager] removeFileAtPath:[savePanel filename] handler:NULL];
	
	/* Destroy local QCRenderer */
	[renderer release];
	
	/* Reset movie */
	GoToBeginningOfMovie(_movie);
	StartMovie(_movie);
	
	/* Update user interface */
	[progressIndicator stopAnimation:nil];
	[progressIndicator setIndeterminate:YES];
	
	/* Restart preview timer */
	_timer = [[NSTimer timerWithTimeInterval:(1.0 / kPreviewFPS) target:self selector:@selector(_previewTimer:) userInfo:nil repeats:YES] retain];
	[[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSEventTrackingRunLoopMode];
}

@end
