#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

#import "PBufferRenderer.h"

@interface AppController : NSObject
{
	IBOutlet NSView*			renderView;
	
	NSOpenGLContext*			_glContext;
	NSOpenGLPixelFormat*		_glPixelFormat;
	PBufferRenderer*			_pBufferRenderer;
	NSTimer*					_renderTimer;
	NSTimeInterval				_startTime;
}
- (IBAction) openComposition:(id)sender;
@end
