#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

/* Custom subclass of QCView that retrieves that video images captured by the composition and forwards them to the Composition Picker panel */
@interface AppView : QCView
@end

@interface AppController : NSObject
{
	IBOutlet NSWindow*						window;
	IBOutlet AppView*						qcView;
}
/* Actions called from the user interface */
- (IBAction) toggleCompositionPicker:(id)sender;
- (IBAction) savePNG:(id)sender;
@end
