#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface RenderView : QCView
@end

@interface AppController : NSObject
{
	IBOutlet NSPanel*				mainPanel;
	IBOutlet RenderView*			renderView;
	IBOutlet NSTextField*			locationField;
}
- (void) editLocation;
- (IBAction) updateLocation:(id)sender;
@end
