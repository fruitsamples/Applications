#import "MyDocument.h"

@implementation MyDocument

- (void) dealloc
{
	/* Unregister from composition picker panel notifications */
	[[NSNotificationCenter defaultCenter] removeObserver:self name:QCCompositionPickerPanelDidSelectCompositionNotification object:nil];
	
	[super dealloc];
}

- (NSString*) windowNibName
{
	return @"MyDocument";
}

- (void) windowControllerDidLoadNib:(NSWindowController*)aController
{
	QCCompositionPickerPanel*					panel = [QCCompositionPickerPanel sharedCompositionPickerPanel];
	NSView*										contentView = [[aController window] contentView];
	
	[super windowControllerDidLoadNib:aController];
    
	/* Make the text view and its scrollview transparent */
	[textView setDrawsBackground:NO];
	[scrollView setDrawsBackground:NO];
	
	/* Load the RTF data in the text view if available or use some default text */
	if(_rtfData) {
		[textView replaceCharactersInRange:NSMakeRange(0, 0) withRTF:_rtfData];
		[_rtfData release];
	}
	else {
		[textView replaceCharactersInRange:NSMakeRange(0, 0) withString:@"Type some text here or select a composition in the picker..."];
		[textView setTextColor:[NSColor whiteColor]];
		[textView setFont:[NSFont systemFontOfSize:24]];
		[textView setSelectedRange:NSMakeRange(0, [[textView textStorage] length])];
	}
	
	/* Configure and show the composition picker panel - only the first time this method is ran */
	if(![[[panel compositionPickerView] compositions] count]) {
		[[panel compositionPickerView] setCompositionsFromRepositoryWithProtocol:QCCompositionProtocolGraphicAnimation andAttributes:nil];
		[panel orderFront:nil];
	}
	
	/* Register for composition picker panel notifications */
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didSelectComposition:) name:QCCompositionPickerPanelDidSelectCompositionNotification object:nil];
	
	/* Set up Core Animation */
	[contentView setLayer:[QCCompositionLayer compositionLayerWithComposition:[[panel compositionPickerView] selectedComposition]]];
	[contentView setWantsLayer:YES];
}

- (NSData*) dataRepresentationOfType:(NSString *)aType
{
	/* Return the text view contents as RTF data */
	return [[textView textStorage] RTFFromRange:NSMakeRange(0, [[textView textStorage] length]) documentAttributes:nil];
}

- (BOOL) loadDataRepresentation:(NSData*)data ofType:(NSString*)aType
{
	/* Save RTF data for -windowControllerDidLoadNib: */
	_rtfData = [data copy];
	
	return YES;
}

- (void) _didSelectComposition:(NSNotification*)notification
{
	QCComposition*						composition = [[notification userInfo] objectForKey:@"QCComposition"];
	NSWindow*							window = [[[self windowControllers] objectAtIndex:0] window];
	
	/* Replace the content view of the window with a Quartz Composer layer with the selected composition */
	[[window contentView] setLayer:[QCCompositionLayer compositionLayerWithComposition:composition]];
}

@end

@implementation MyDocument (FirstResponderActions)

- (IBAction) orderFrontFontPanel:(id)sender
{
	[[NSFontManager sharedFontManager] orderFrontFontPanel:sender];
}

- (IBAction) orderFrontCompositionPanel:(id)sender
{
	[[QCCompositionPickerPanel sharedCompositionPickerPanel] orderFront:sender];
}

@end
