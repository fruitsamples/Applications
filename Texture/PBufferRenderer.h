#import <AppKit/AppKit.h>
#import <Quartz/Quartz.h>
#import <OpenGL/gl.h>

@interface PBufferRenderer : NSObject
{
	NSOpenGLPixelBuffer*		_pixelBuffer;
	NSOpenGLContext*			_pixelBufferContext;
	QCRenderer*					_renderer;
	NSOpenGLContext*			_textureContext;
	GLenum						_textureTarget;
	GLuint						_textureName;
}
- (id) initWithCompositionPath:(NSString*)path textureTarget:(GLenum)target textureWidth:(unsigned)width textureHeight:(unsigned)height openGLContext:(NSOpenGLContext*)context;
- (BOOL) updateTextureForTime:(NSTimeInterval)time;
- (GLenum) textureTarget;
- (GLuint) textureName;
- (unsigned) textureWidth;
- (unsigned) textureHeight;
- (float) textureCoordSMin;
- (float) textureCoordSMax;
- (float) textureCoordTMin;
- (float) textureCoordTMax;
@end
