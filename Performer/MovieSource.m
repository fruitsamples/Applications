#ifdef MAC_OS_X_VERSION_10_5
#import <QTKit/QTKit.h>
#else
#import <QuickTime/QuickTime.h>
#endif

#import "MediaSource.h"

@interface MovieSource : MediaSource
{
#ifdef MAC_OS_X_VERSION_10_5
	QTMovie*					_movie;
#else
	NSOpenGLContext*			_glContext;
	NSOpenGLPixelFormat*		_glPixelFormat;
	QTVisualContextRef			_visualContext;
	Movie						_movie;
#endif
}
@end

@implementation MovieSource

+ (void) load
{
	//Register automatically this MediaSource subclass when the Obj-C runtime loads it
	[MediaSource registerMediaSourceClass:[self class]];
	
#ifndef MAC_OS_X_VERSION_10_5
	//We also need to initialize QuickTime
	EnterMovies();
#endif
}

+ (NSArray*) supportedFileExtensions
{
	//We handle movie files types (make sure QuickTime does not handle Quartz Composer ".qtz" files as there is an explicit media source class for them)
	return [NSArray arrayWithObjects:@"mov", @"avi", @"dv", @"mpg", nil];
}

- (id) initWithFile:(NSString*)path openGLContext:(NSOpenGLContext*)context pixelFormat:(NSOpenGLPixelFormat*)pixelFormat
{
#ifndef MAC_OS_X_VERSION_10_5
	Boolean						active = TRUE;
	QTNewMoviePropertyElement	properties[] = {
									{kQTPropertyClass_DataLocation, kQTDataLocationPropertyID_CFStringNativePath, sizeof(CFStringRef), &path, 0},
									{kQTPropertyClass_NewMovieProperty, kQTNewMoviePropertyID_Active, sizeof(Boolean), &active, 0},
									{kQTPropertyClass_Context, kQTContextPropertyID_VisualContext, sizeof(QTVisualContextRef), &_visualContext, 0}
								};
	OSStatus					error;
#endif
	
	if(self = [super init]) {
#ifdef MAC_OS_X_VERSION_10_5
		//Open the movie
		_movie = [[QTMovie alloc] initWithFile:path error:NULL];
		
		//Check for errors
		if(_movie == nil) {
			[self release];
			return nil;
		}
		
		//Make the movie loop continuously
		[_movie setAttribute:[NSNumber numberWithBool:YES] forKey:QTMovieLoopsAttribute];
		
		//Start playing movie immediately
		[_movie gotoBeginning];
		[_movie play];
#else
		//Make sure the OpenGL context will not go away
		_glContext = [context retain];
		_glPixelFormat = [pixelFormat retain];
		
		//Create a pixel buffer visual context to play the movie into
		error = QTOpenGLTextureContextCreate(NULL, [context CGLContextObj], [pixelFormat CGLPixelFormatObj], NULL, &_visualContext);
		
		//Open the movie
		if(error == noErr)
		error = NewMovieFromProperties(sizeof(properties) / sizeof(QTNewMoviePropertyElement), properties, 0, NULL, &_movie);
		
		//Check for errors
		if(error != noErr) {
			[self release];
			return nil;
		}
		
		//Make sure movie plays in high-quality (much better for DV content) - FIXME: Should we specify "hintsDeinterlaceFields" too?
		SetMoviePlayHints(_movie, hintsHighQuality, hintsHighQuality);
		
		//Make the movie loop continuously
		SetTimeBaseFlags(GetMovieTimeBase(_movie), loopTimeBase);
		
		//Start playing movie immediately
		GoToBeginningOfMovie(_movie);
		StartMovie(_movie);
#endif
	}
	
	return self;
}

- (BOOL) isNewImageAvailableForTime:(const CVTimeStamp*)time
{
#ifdef MAC_OS_X_VERSION_10_5
	//Assume we always have a new image available
	return YES;
#else
	//Give some time to QuickTime
	MoviesTask(_movie, 0);
	
	//Give some time to the visual context
	QTVisualContextTask(_visualContext); 
	
	//Check if we have a new image available
	return QTVisualContextIsNewImageAvailable(_visualContext, time);
#endif
}

- (id) copyImageForTime:(const CVTimeStamp*)time
{
#ifdef MAC_OS_X_VERSION_10_5
	return [[_movie currentFrameImage] retain];
#else
	CVOpenGLTextureRef				imageBuffer;
	
	//Retrieve an image
	if(QTVisualContextCopyImageForTime(_visualContext, NULL, time, &imageBuffer) != kCVReturnSuccess)
	return NULL;
	
	return (id)imageBuffer;
#endif
}

- (void) dealloc
{
	//Release all objects
#ifdef MAC_OS_X_VERSION_10_5
	[_movie stop];
	[_movie release];
#else
	if(_movie) {
		StopMovie(_movie);
		DisposeMovie(_movie);
	}
	if(_visualContext)
	QTVisualContextRelease(_visualContext);
	[_glContext release];
	[_glPixelFormat release];
#endif
	
	[super dealloc];
}

@end
