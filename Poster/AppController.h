#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

/* Custom subclass of QCView that retrieves the current rendering time and passes it to the AppController */
@interface AppView : QCView
@end

@interface AppController : NSObject
{
	IBOutlet NSWindow*				window;
	IBOutlet AppView*				qcView;
	
	/* Those values are bound to controls in the user interface*/
	unsigned						posterWidth,
									posterHeight,
									tilingFactor;
									
	NSString*						_compositionPath;
	NSTimeInterval					_renderTime;
}
- (void) setRenderTime:(NSTimeInterval)time;

/* Actions called from the user interface */
- (IBAction) loadComposition:(id)sender;
- (IBAction) exportPoster:(id)sender;
@end
