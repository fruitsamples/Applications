#import "FrameCompressor.h"

@interface FrameMovieExporter : FrameCompressor
{
	Movie					_movie;
	DataHandler				_dataHandler;
	Track					_track;
	Media					_media;
}
- (id) initWithPath:(NSString*)path codec:(CodecType)codec pixelsWide:(unsigned)width pixelsHigh:(unsigned)height options:(ICMCompressionSessionOptionsRef)options;
- (BOOL) exportFrame:(CVPixelBufferRef)frame timeStamp:(NSTimeInterval)timestamp;
@end
