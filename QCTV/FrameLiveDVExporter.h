#import "FrameCompressor.h"

typedef enum {
	kDVFormat_NTSC,
	kDVFormat_PAL
} DVFormat;

@interface FrameLiveDVExporter : FrameCompressor
{
	ImageSequence			_displayImageSequence;
	PixMapHandle			_displayPixMap;
	ImageDescriptionHandle	_displayImageDescription;
	ComponentInstance		_displayComponent;
}
+ (NSSize) sizeForFormat:(DVFormat)format;
+ (float) framerateForFormat:(DVFormat)format;

- (id) initWithDVFormat:(DVFormat)format progressive:(BOOL)progressive wideScreen:(BOOL)wide;
- (BOOL) exportFrame:(CVPixelBufferRef)frame;
@end
