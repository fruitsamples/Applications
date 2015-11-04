#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <QuickTime/QuickTime.h>

/* Customized NSImageView that allows us to override the drag & drop behavior */
@interface ImageView : NSImageView
@end

@interface AppController : NSObject
{
	IBOutlet NSWindow*						window;
	IBOutlet QCView*						qcView;
	IBOutlet QCCompositionParameterView*	parameterView;
	IBOutlet QCCompositionPickerView*		pickerView;
	IBOutlet NSButton*						exportButton;
	IBOutlet NSProgressIndicator*			progressIndicator;
	
	NSTimer*								_timer;
	QCRenderer*								_renderer;
	QTVisualContextRef						_visualContext;
	Movie									_movie;
}
/* Called from the customized NSImageView */
- (BOOL) loadMovie:(NSString*)path;

/* Called from the user interface */
- (IBAction) performExport:(id)sender;
@end
