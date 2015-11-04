#import <OpenGL/CGLMacro.h>

#import "FrameReader.h"

@implementation FrameReader

- (id) init
{
	//Make sure client goes through designated initializer
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (id) initWithOpenGLContext:(NSOpenGLContext*)context pixelsWide:(unsigned)width pixelsHigh:(unsigned)height asynchronousFetching:(BOOL)asynchronous
{
	//IMPORTANT: We use the macros provided by <OpenGL/CGLMacro.h> which provide better performances and allows us not to bother with making sure the current context is valid
	CGLContextObj					cgl_ctx = [context CGLContextObj];
	GLint							save1,
									save2,
									save3,
									save4;
	CVReturn						theError;
	NSMutableDictionary*			attributes;
	
	//Check parameters
	if((context == nil) || ((width == 0) || (height == 0))) {
		[self release];
		return nil;
	}
	
	if(self = [super init]) {
		//Keep essential parameters around
		_glContext = [context retain];
		_width = width;
		_height = height;
		
		//Create memory buffers - Make sure the buffers are paged-aligned and rowbytes is a multiple of 64 for performance reasons
		_bufferRowBytes = (_width * 4 + 63) & ~63;
		if(asynchronous) {
			_frameBuffers[0] = valloc(_height * _bufferRowBytes);
			_frameBuffers[1] = valloc(_height * _bufferRowBytes);
		}
		else
		_frameBuffer = valloc(_height * _bufferRowBytes);
		if((asynchronous && (!_frameBuffers[0] || !_frameBuffers[1])) || (!asynchronous && !_frameBuffer)) {
			NSLog(@"Memory allocation failed");
			[self release];
			return nil;
		}
		
		//Create OpenGL textures - For extra safety, save & restore OpenGL states that are changed
		if(asynchronous) {
			//Create and configure first texture
			glGenTextures(1, &_textureNames[0]);
			glGetIntegerv(GL_TEXTURE_BINDING_RECTANGLE_EXT, &save1);
			glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _textureNames[0]);
			glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);
			glGetIntegerv(GL_UNPACK_ALIGNMENT, &save2);
			glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
			glGetIntegerv(GL_UNPACK_ROW_LENGTH, &save3);
			glPixelStorei(GL_UNPACK_ROW_LENGTH, _bufferRowBytes / 4);
			glGetIntegerv(GL_UNPACK_CLIENT_STORAGE_APPLE, &save4);
			glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
#if __BIG_ENDIAN__
			glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA, _width, _height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, _frameBuffers[0]);
#else
			glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA, _width, _height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8, _frameBuffers[0]);
#endif
			glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, save4);
			glPixelStorei(GL_UNPACK_ROW_LENGTH, save3);
			glPixelStorei(GL_UNPACK_ALIGNMENT, save2);
			glBindTexture(GL_TEXTURE_RECTANGLE_EXT, save1);
			
			//Create and configure second texture
			glGenTextures(1, &_textureNames[1]);
			glGetIntegerv(GL_TEXTURE_BINDING_RECTANGLE_EXT, &save1);
			glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _textureNames[1]);
			glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);
			glGetIntegerv(GL_UNPACK_ALIGNMENT, &save2);
			glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
			glGetIntegerv(GL_UNPACK_ROW_LENGTH, &save3);
			glPixelStorei(GL_UNPACK_ROW_LENGTH, _bufferRowBytes / 4);
			glGetIntegerv(GL_UNPACK_CLIENT_STORAGE_APPLE, &save4);
			glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
#if __BIG_ENDIAN__
			glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA, _width, _height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, _frameBuffers[1]);
#else
			glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA, _width, _height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8, _frameBuffers[1]);
#endif
			glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, save4);
			glPixelStorei(GL_UNPACK_ROW_LENGTH, save3);
			glPixelStorei(GL_UNPACK_ALIGNMENT, save2);
			glBindTexture(GL_TEXTURE_RECTANGLE_EXT, save1);
			
			//Check for OpenGL errors
			theError = glGetError();
			if(theError) {
				NSLog(@"OpenGL texture creation failed (error 0x%04X)", theError);
				[self release];
				return nil;
			}
		}
		
		//Create buffer pool
		attributes = [NSMutableDictionary dictionary];
		[attributes setObject:[NSNumber numberWithUnsignedInt:k32ARGBPixelFormat] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
		[attributes setObject:[NSNumber numberWithUnsignedInt:width] forKey:(NSString*)kCVPixelBufferWidthKey];
		[attributes setObject:[NSNumber numberWithUnsignedInt:height] forKey:(NSString*)kCVPixelBufferHeightKey];
		theError = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (CFDictionaryRef)attributes, &_bufferPool);
		if(theError) {
			NSLog(@"CVPixelBufferPoolCreate() failed with error %i", theError);
			[self release];
			return nil;
		}
		
		//If we use asynchronous fetching, we need to skip the first buffer which will contain undefined pixels
		_skipFirstBuffer = asynchronous;
	}
	
	return self;
}

- (void) dealloc
{
	//IMPORTANT: We use the macros provided by <OpenGL/CGLMacro.h> which provide better performances and allows us not to bother with making sure the current context is valid
	CGLContextObj					cgl_ctx = [_glContext CGLContextObj];
	
	//Destroy resources
	if(_bufferPool)
	CVPixelBufferPoolRelease(_bufferPool);
	if(_frameBuffer)
	free(_frameBuffer);
	if(_frameBuffers[0])
	free(_frameBuffers[0]);
	if(_textureNames[0])
	glDeleteTextures(1, &_textureNames[0]);
	if(_frameBuffers[1])
	free(_frameBuffers[1]);
	if(_textureNames[1])
	glDeleteTextures(1, &_textureNames[1]);
	
	//Release context
	[_glContext release];
	
	[super dealloc];
}

- (CVPixelBufferRef) readFrame
{
	//IMPORTANT: We use the macros provided by <OpenGL/CGLMacro.h> which provide better performances and allows us not to bother with making sure the current context is valid
	CGLContextObj					cgl_ctx = [_glContext CGLContextObj];
	GLint							save1,
									save2,
									save3;
	unsigned char*					src;
    unsigned char*					dst;
	unsigned						i;
	CVReturn						theError;
	CVPixelBufferRef				pixelBuffer;
	unsigned char*					baseAddress;
	unsigned						rowbytes;
	
	//Get image from OpenGL context
	if(_frameBuffer) {
		//Read OpenGL context pixels directly
		glGetIntegerv(GL_PACK_ALIGNMENT, &save1);
		glPixelStorei(GL_PACK_ALIGNMENT, 4);
		glGetIntegerv(GL_PACK_ROW_LENGTH, &save2);
		glPixelStorei(GL_PACK_ROW_LENGTH, _bufferRowBytes / 4);
#if __BIG_ENDIAN__
		glReadPixels(0, 0, _width, _height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, _frameBuffer);
#else
		glReadPixels(0, 0, _width, _height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8, _frameBuffer);
#endif
		glPixelStorei(GL_PACK_ROW_LENGTH, save2);
		glPixelStorei(GL_PACK_ALIGNMENT, save1);
	}
	else {
		//Copy OpenGL context pixels to non-current texture
		glGetIntegerv(GL_TEXTURE_BINDING_RECTANGLE_EXT, &save1);
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _textureNames[1 - _currentTextureIndex]);
		glCopyTexSubImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, 0, 0, 0, 0, _width, _height);
		
		//Read pixels from current texture
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _textureNames[_currentTextureIndex]);
		glGetIntegerv(GL_PACK_ALIGNMENT, &save2);
		glPixelStorei(GL_PACK_ALIGNMENT, 4);
		glGetIntegerv(GL_PACK_ROW_LENGTH, &save3);
		glPixelStorei(GL_PACK_ROW_LENGTH, _bufferRowBytes / 4);
#if __BIG_ENDIAN__
		glGetTexImage(GL_TEXTURE_RECTANGLE_EXT, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, _frameBuffers[_currentTextureIndex]);
#else
		glGetTexImage(GL_TEXTURE_RECTANGLE_EXT, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8, _frameBuffers[_currentTextureIndex]);
#endif
		glPixelStorei(GL_PACK_ROW_LENGTH, save3);
		glPixelStorei(GL_PACK_ALIGNMENT, save2);
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, save1);
	}
	
	//Check for OpenGL errors
	theError = glGetError();
	if(theError) {
		NSLog(@"OpenGL pixels read failed (error 0x%04X)", theError);
		return NULL;
	}
	
	//Check if this image is valid
	if(_skipFirstBuffer) {
		_skipFirstBuffer = NO;
		return NULL;
	}
	
	//Get pixel buffer from pool
	theError = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _bufferPool, &pixelBuffer);
	if(theError) {
		NSLog(@"CVPixelBufferPoolCreatePixelBuffer() failed with error %i", theError);
		return NULL;
	}
	
	//Lock pixel buffer bits
	theError = CVPixelBufferLockBaseAddress(pixelBuffer, 0);
	if(theError) {
		NSLog(@"CVPixelBufferLockBaseAddress() failed with error %i", theError);
		return NULL;
	}
	baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
	rowbytes = CVPixelBufferGetBytesPerRow(pixelBuffer);
	
	//Copy image to pixel buffer vertically flipped - OpenGL copies pixels upside-down
	if(_frameBuffer) {
		for(i = 0; i < _height; ++i) {
			src = _frameBuffer + _bufferRowBytes * i;
			dst = baseAddress + rowbytes * (_height - 1 - i);
			bcopy(src, dst, _width * 4);
		}
	}
	else {
		for(i = 0; i < _height; ++i) {
			src = _frameBuffers[_currentTextureIndex] + _bufferRowBytes * i;
			dst = baseAddress + rowbytes * (_height - 1 - i);
			bcopy(src, dst, _width * 4);
		}
	}
	
	//Unlock pixel buffer
	CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
	
	//Toggle current texture index if necesary
	if(!_frameBuffer)
	_currentTextureIndex = 1 - _currentTextureIndex;
	
	return (CVPixelBufferRef)[(id)pixelBuffer autorelease];
}

@end
