#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface AppController : NSObject
{
	/* The pop-up button to select a composition */
	IBOutlet NSPopUpButton*					compositionChoice;
	
	/* The QCView to display the selected composition */
	IBOutlet QCView*						qcView;
	
@private
	/* Map between the display name of compositions and QCComposition objects */
	NSMutableDictionary*					_mapNameToComposition;
}

/* Called when a new composition is selected */
- (IBAction) compositionChanged:(id)sender;
@end
