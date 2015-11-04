#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface FrameReader : NSObject
{
	NSOpenGLContext*			_glContext;
	unsigned					_width,
								_height;
	CVPixelBufferPoolRef		_bufferPool;
	unsigned					_bufferRowBytes;
	void*						_frameBuffer;
	void*						_frameBuffers[2];
	unsigned int				_textureNames[2]; //GLuint
	unsigned					_currentTextureIndex;
	BOOL						_skipFirstBuffer;
}
- (id) initWithOpenGLContext:(NSOpenGLContext*)context pixelsWide:(unsigned)width pixelsHigh:(unsigned)height asynchronousFetching:(BOOL)asynchronous;
- (CVPixelBufferRef) readFrame;
@end
