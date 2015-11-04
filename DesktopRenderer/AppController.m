#import "AppController.h"

@implementation RenderView

- (void) mouseDown:(NSEvent*)event
{
	/* If there is a option-click, edit report location field */
	if([event modifierFlags] & NSAlternateKeyMask)
	[(AppController*)[NSApp delegate] editLocation];
	else
	[super mouseDown:event];
}

- (BOOL) renderAtTime:(NSTimeInterval)time arguments:(NSDictionary*)arguments
{
	BOOL			success = [super renderAtTime:time arguments:arguments];
	
	/* Set window to report name */
	if(success)
	[[self window] setTitle:[self valueForOutputKey:@"reportName"]];
	
	return success;
}

@end

@implementation AppController

- (void) applicationWillFinishLaunching:(NSNotification*)notification
{
	NSString*		path = [[NSBundle mainBundle] pathForResource:@"Composition" ofType:@"qtz"];
	
	/* Put panel just above Desktop */
	[mainPanel setLevel:kCGDesktopWindowLevel];
	
	/* Load composition */
	path = [[NSBundle mainBundle] pathForResource:@"Composition" ofType:@"qtz"];
	if((path == nil) || ![renderView loadCompositionFromFile:path])
	[NSApp terminate:nil];
	
	/* Configure composition to use default report URL */
	path = [[NSBundle mainBundle] pathForResource:@"Report" ofType:@"xml"];
	if(path == nil)
	[NSApp terminate:nil];
	path = [[NSURL fileURLWithPath:path] absoluteString];
	[renderView setValue:path forInputKey:@"reportURL"];
	
	/* Make sure QCView only renders at most once per minute */
	[renderView setMaxRenderingFrameRate:(1.0 / 60.0)];
}

- (void) applicationDidFinishLaunching:(NSNotification*)notification
{
	/* Show panel */
	[mainPanel makeKeyAndOrderFront:nil];
	
	/* Start rendering */
	[renderView startRendering];
}

- (void) editLocation
{
	/* Update location text field */
	[locationField setStringValue:[renderView valueForInputKey:@"reportURL"]];
	
	/* Show location text field */
	[renderView setHidden:YES];
	[locationField setHidden:NO];
}

- (IBAction) updateLocation:(id)sender
{
	NSString*				location = [locationField stringValue];
	NSURL*					url;
	
	/* Convert specified location to an URL */
	if([location length]) {
		if([location characterAtIndex:0] == '/')
		url = [NSURL fileURLWithPath:location];
		else
		url = [NSURL URLWithString:location];
	}
	
	/* Update composition report URL if applicable */
	if(url)
	[renderView setValue:[url absoluteString] forInputKey:@"reportURL"];
	
	/* Hide location text field */
	[locationField setHidden:YES];
	[renderView setHidden:NO];
}

- (void) windowWillClose:(NSNotification*)notification
{
	/* Quit application */
	[NSApp terminate:nil];
}

@end
