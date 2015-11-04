#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

/* Customized subclass of QCView that allows looping in time */
@interface AppView : QCView
{
	NSTimeInterval				_loopTime;
}
- (void) setLoopTime:(NSTimeInterval)loopTime;
- (NSTimeInterval) loopTime;
@end

/* The application controller class */
@interface AppController : NSObject
{
	/* The QCView to render the selected composition with */
	IBOutlet AppView*			qcView;
	
	/* The application main window */
	IBOutlet NSWindow*			window;
	
	/* Set to YES if we are browsing transitions */
	BOOL						_transitionMode;
}
- (IBAction) selectProtocol:(id)sender;
- (IBAction) toggleFullScreen:(id)sender;
@end
