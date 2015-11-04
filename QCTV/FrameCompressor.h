#import <Cocoa/Cocoa.h>
#import <QuickTime/QuickTime.h>

@interface FrameCompressor : NSObject
{
	ICMCompressionSessionRef	_compressionSession;
}
+ (ICMCompressionSessionOptionsRef) defaultOptions;
+ (ICMCompressionSessionOptionsRef) userOptions:(CodecType*)outCodecType frameRate:(double*)outFrameRate autosaveName:(NSString*)name;

- (id) initWithCodec:(CodecType)codec pixelsWide:(unsigned)width pixelsHigh:(unsigned)height options:(ICMCompressionSessionOptionsRef)options;
- (BOOL) compressFrame:(CVPixelBufferRef)frame timeStamp:(NSTimeInterval)timestamp duration:(NSTimeInterval)duration;
- (BOOL) flushFrames;

- (void) doneCompressingFrame:(ICMEncodedFrameRef)frame;
@end
