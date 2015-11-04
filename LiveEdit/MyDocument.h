#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface MyDocument : NSDocument
{
	IBOutlet NSTextView*			textView;
	IBOutlet NSScrollView*			scrollView;
	
	/* To store temporarily the RTF data read from disk */
	NSData*							_rtfData;
}
@end

/* This actions are called from the Edit menu items as defined in the nib file */
@interface MyDocument (FirstResponderActions)
- (IBAction) orderFrontFontPanel:(id)sender;
- (IBAction) orderFrontCompositionPanel:(id)sender;
@end
