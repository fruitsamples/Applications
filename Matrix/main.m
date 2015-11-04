#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#ifdef MAC_OS_X_VERSION_10_5
#import <QTKit/QTKit.h>
#else
#import <QuickTime/QuickTime.h>
#endif

#define kRendererEventMask (NSLeftMouseDownMask | NSLeftMouseDraggedMask | NSLeftMouseUpMask | NSRightMouseDownMask | NSRightMouseDraggedMask | NSRightMouseUpMask | NSOtherMouseDownMask | NSOtherMouseUpMask | NSOtherMouseDraggedMask | NSKeyDownMask | NSKeyUpMask | NSFlagsChangedMask | NSScrollWheelMask | NSTabletPointMask | NSTabletProximityMask)
#define kRendererFPS 60.0
#define kFramesCacheMaxSize 10
#define kFramesCacheInputKey @"Frames"

@interface MatrixApplication : NSApplication
{
	NSOpenGLContext*			_openGLContext;
	QCRenderer*					_renderer;
	NSString*					_filePath;
	NSTimer*					_renderTimer;
	NSTimeInterval				_startTime;
	NSSize						_screenSize;
#ifdef MAC_OS_X_VERSION_10_5
	QTMovie*					_movie;
#else
	Movie						_movie;
	QTVisualContextRef			_visualContext;
#endif
	NSMutableArray*				_framesCache;
}
@end

@implementation MatrixApplication

- (id) init
{
	//We need to be our own delegate
	if(self = [super init])
	[self setDelegate:self];
	
	return self;
}

- (BOOL) application:(NSApplication*)theApplication openFile:(NSString*)filename
{
	//Let's remember the file for later
	_filePath = [filename retain];
	
	return YES;
}

- (void) applicationDidFinishLaunching:(NSNotification*)aNotification 
{
	Boolean							active = TRUE;
#ifndef MAC_OS_X_VERSION_10_5
	QTNewMoviePropertyElement		properties[] = {
														{kQTPropertyClass_DataLocation, kQTDataLocationPropertyID_CFStringNativePath, sizeof(CFStringRef), &_filePath, 0},
														{kQTPropertyClass_NewMovieProperty, kQTNewMoviePropertyID_Active, sizeof(Boolean), &active, 0},
														{kQTPropertyClass_Context, kQTContextPropertyID_VisualContext, sizeof(QTVisualContextRef), &_visualContext, 0}
									};
#endif
	GLint							value = 1;
	NSOpenGLPixelFormatAttribute	attributes[] = {
														NSOpenGLPFAFullScreen,
														NSOpenGLPFAScreenMask, CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),
														NSOpenGLPFANoRecovery,
														NSOpenGLPFADoubleBuffer,
														NSOpenGLPFAAccelerated,
														NSOpenGLPFADepthSize, 24,
														(NSOpenGLPixelFormatAttribute) 0
													};
	NSOpenGLPixelFormat*			format = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] autorelease];
	NSOpenPanel*					openPanel;
	OSStatus						error;
	
	//If no movie file was dropped on the application's icon, we need to ask the user for one
	if(_filePath == nil) {
		openPanel = [NSOpenPanel openPanel];
		[openPanel setAllowsMultipleSelection:NO];
		[openPanel setCanChooseDirectories:NO];
		[openPanel setCanChooseFiles:YES];
		if([openPanel runModalForDirectory:nil file:nil types:[NSArray arrayWithObject:@"mov"]] != NSOKButton) {
			NSLog(@"No movie file specified");
			[NSApp terminate:nil];
		}
		_filePath = [[openPanel filename] retain];
	}
	
	//Capture the main screen and cache its dimensions
	CGDisplayCapture(kCGDirectMainDisplay);
	_screenSize.width = CGDisplayPixelsWide(kCGDirectMainDisplay);
	_screenSize.height = CGDisplayPixelsHigh(kCGDirectMainDisplay);
	
	//Create the fullscreen OpenGL context on the main screen (double-buffered with color and depth buffers)
	_openGLContext = [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil];
	if(_openGLContext == nil) {
		NSLog(@"Cannot create OpenGL context");
		[NSApp terminate:nil];
	}
	[_openGLContext setFullScreen];
	[_openGLContext setValues:&value forParameter:kCGLCPSwapInterval];
	
#ifdef MAC_OS_X_VERSION_10_5
	_movie = [[QTMovie alloc] initWithFile:_filePath error:NULL];
	if(_movie == nil) {
		NSLog(@"Cannot open movie");
		[NSApp terminate:nil];
	}
	[_movie setAttribute:[NSNumber numberWithBool:YES] forKey:QTMovieLoopsAttribute];
	[_movie gotoBeginning];
#else
	//Create a QuickTime visual context with that OpenGL context and open the movie on it
	error = QTOpenGLTextureContextCreate(NULL, [_openGLContext CGLContextObj], [format CGLPixelFormatObj], NULL, &_visualContext);
	if(error == noErr)
	error = NewMovieFromProperties(sizeof(properties) / sizeof(QTNewMoviePropertyElement), properties, 0, NULL, &_movie);
	if(error != noErr) {
		NSLog(@"Cannot open movie");
		[NSApp terminate:nil];
	}
	SetMoviePlayHints(_movie, hintsHighQuality, hintsHighQuality);
	SetTimeBaseFlags(GetMovieTimeBase(_movie), loopTimeBase);
	GoToBeginningOfMovie(_movie);
#endif
	
	//Create movie frames cache
	_framesCache = [NSMutableArray new];
	
	//Create the QuartzComposer Renderer with that OpenGL context and the predefined composition file
	_renderer = [[QCRenderer alloc] initWithOpenGLContext:_openGLContext pixelFormat:format file:[[NSBundle mainBundle] pathForResource:@"Matrix" ofType:@"qtz"]];
	if(_renderer == nil) {
		NSLog(@"Cannot create QCRenderer");
		[NSApp terminate:nil];
	}
	
	//Create a timer which will regularly call our rendering method
	_renderTimer = [[NSTimer scheduledTimerWithTimeInterval:(1.0 / (NSTimeInterval)kRendererFPS) target:self selector:@selector(_render:) userInfo:nil repeats:YES] retain];
	if(_renderTimer == nil) {
		NSLog(@"Cannot create NSTimer");
		[NSApp terminate:nil];
	}
	
	//Start playing movie
#ifdef MAC_OS_X_VERSION_10_5
	[_movie play];
#else
	StartMovie(_movie);
#endif
}

- (void) renderWithEvent:(NSEvent*)event
{
	NSTimeInterval			time = [NSDate timeIntervalSinceReferenceDate];
	NSPoint					mouseLocation;
	NSMutableDictionary*	arguments;
#ifdef MAC_OS_X_VERSION_10_5
	NSImage*				nsImage;
#else
	CVOpenGLTextureRef		imageBuffer;
#endif
	
	//Let's compute our local time
	if(_startTime == 0) {
		_startTime = time;
		time = 0;
	}
	else
	time -= _startTime;
	
	//We set up the arguments to pass to the composition (normalized mouse coordinates and an optional event)
	mouseLocation = [NSEvent mouseLocation];
	mouseLocation.x /= _screenSize.width;
	mouseLocation.y /= _screenSize.height;
	arguments = [NSMutableDictionary dictionaryWithObject:[NSValue valueWithPoint:mouseLocation] forKey:QCRendererMouseLocationKey];
	if(event)
	[arguments setObject:event forKey:QCRendererEventKey];
	
#ifdef MAC_OS_X_VERSION_10_5
	nsImage = [_movie currentFrameImage];
	if(nsImage) {
		//Update movie frames cache
		[_framesCache insertObject:nsImage atIndex:0];
		if([_framesCache count] > kFramesCacheMaxSize)
		[_framesCache removeLastObject];
		
		//Pass updated movie frames cache to the composition
		if(![_renderer setValue:_framesCache forInputKey:kFramesCacheInputKey])
		NSLog(@"Could not pass frames cache to composition");
	}
#else
	//Give some idle time to QuickTime
	MoviesTask(_movie, 0);
	QTVisualContextTask(_visualContext);
	
	//Check if a new frame is available from the movie
	if(QTVisualContextIsNewImageAvailable(_visualContext, NULL) && (QTVisualContextCopyImageForTime(_visualContext, NULL, NULL, &imageBuffer) == kCVReturnSuccess)) {
		//Update movie frames cache
		[_framesCache insertObject:(id)imageBuffer atIndex:0];
		if([_framesCache count] > kFramesCacheMaxSize)
		[_framesCache removeLastObject];
		CVOpenGLTextureRelease(imageBuffer);
		
		//Pass updated movie frames cache to the composition
		if(![_renderer setValue:_framesCache forInputKey:kFramesCacheInputKey])
		NSLog(@"Could not pass frames cache to composition");
	}
#endif
	
	//Render a frame from the composition
	if(![_renderer renderAtTime:time arguments:arguments])
	NSLog(@"Rendering failed at time %.3fs", time);
	
	//Flush the OpenGL context to display the frame on screen
	[_openGLContext flushBuffer];
}

- (void) _render:(NSTimer*)timer
{
	//Simply call our rendering method, passing no event to the composition
	[self renderWithEvent:nil];
}

- (void) sendEvent:(NSEvent*)event
{
	//If the user pressed the [Esc] key, we need to exit
	if(([event type] == NSKeyDown) && ([event keyCode] == 0x35))
	[NSApp terminate:nil];
	
	//If the renderer is active and we have a meaningful event, render immediately passing that event to the composition
	if(_renderer && (NSEventMaskFromType([event type]) & kRendererEventMask))
	[self renderWithEvent:event];
	else
	[super sendEvent:event];
}

- (void) applicationWillTerminate:(NSNotification*)aNotification 
{
	//Stop the timer
	[_renderTimer invalidate];
	[_renderTimer release];
	
	//Destroy the renderer
	[_renderer release];
	
	//Destroy movie frames cache
	[_framesCache release];
	
	//Destroy the movie
#ifdef MAC_OS_X_VERSION_10_5
	[_movie release];
#else
	if(_movie) {
		StopMovie(_movie);
		DisposeMovie(_movie);
	}
	if(_visualContext)
	QTVisualContextRelease(_visualContext);
#endif
	
	//Destroy the OpenGL context
	[_openGLContext clearDrawable];
	[_openGLContext release];
	
	//Release main screen
	if(CGDisplayIsCaptured(kCGDirectMainDisplay))
	CGDisplayRelease(kCGDirectMainDisplay);
	
	//Release path
	[_filePath release];
}

@end

int main(int argc, const char *argv[])
{
#ifndef MAC_OS_X_VERSION_10_5
	//Initialize QuickTime
	EnterMovies();
#endif
	
	//Start application
	return NSApplicationMain(argc, argv);
}
