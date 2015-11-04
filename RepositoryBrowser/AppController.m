#import "AppController.h"

@implementation AppView

- (void) setLoopTime:(NSTimeInterval)loopTime
{
	_loopTime = loopTime;
}

- (NSTimeInterval) loopTime
{
	return _loopTime;
}

- (void) mouseDragged:(NSEvent*)theEvent
{
	NSPoint								mouse = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSRect								bounds = [self bounds];
	
	/* If the composition has X & Y inputs pass the mouse coordinates */
	if([[self inputKeys] containsObject:QCCompositionInputXKey] && [[self inputKeys] containsObject:QCCompositionInputYKey]) {
		mouse = [[self window] mouseLocationOutsideOfEventStream];
		mouse = [self convertPoint:mouse fromView:nil];
		[self setValue:[NSNumber numberWithFloat:(mouse.x / bounds.size.width)] forInputKey:QCCompositionInputXKey];
		[self setValue:[NSNumber numberWithFloat:(mouse.y / bounds.size.height)] forInputKey:QCCompositionInputYKey];
	}
}

- (BOOL) renderAtTime:(NSTimeInterval)time arguments:(NSDictionary*)arguments
{
	/* If we have a loop time defined, we modify the render time to loop back and forth */
	if(_loopTime > 0.0) {
		time = fmod(time, 2.0 * _loopTime);
		if(time > _loopTime)
		time = 1.0 - time + _loopTime;
	}
	
	return [super renderAtTime:time arguments:arguments];
}

@end

@implementation AppController

- (void) applicationDidFinishLaunching:(NSNotification*)notification
{
	QCCompositionPickerPanel*			panel = [QCCompositionPickerPanel sharedCompositionPickerPanel];
	
	/* We need to allow alpha selection in the color picker */
	[NSColor setIgnoresAlpha:NO];
	
	/* Configure the composition picker panel */
	[[panel compositionPickerView] setAllowsEmptySelection:YES];
	[[panel compositionPickerView] setCompositionsFromRepositoryWithProtocol:QCCompositionProtocolGraphicAnimation andAttributes:nil];
	[[panel compositionPickerView] setShowsCompositionNames:YES];
	[[panel compositionPickerView] setMaxAnimationFrameRate:30.0];
	
	/* Set default values for the image input parameters */
	[[panel compositionPickerView] setDefaultValue:[NSImage imageNamed:@"Source Image"] forInputKey:QCCompositionInputImageKey];
	[[panel compositionPickerView] setDefaultValue:[NSImage imageNamed:@"Source Image"] forInputKey:QCCompositionInputSourceImageKey];
	[[panel compositionPickerView] setDefaultValue:[NSImage imageNamed:@"Target Image"] forInputKey:QCCompositionInputDestinationImageKey];
	
	/* Show composition picker panel*/
	[panel setFrameOrigin:[window frame].origin];
	[panel orderFront:nil];
	
	/* Register for composition picker panel notifications */
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didSelectComposition:) name:QCCompositionPickerPanelDidSelectCompositionNotification object:nil];
}

- (IBAction) selectProtocol:(id)sender
{
	QCCompositionPickerPanel*			panel = [QCCompositionPickerPanel sharedCompositionPickerPanel];
	NSString*							protocol;
	
	/* Convert the composition protocol index to a protocol name */
	switch([(NSMatrix*)sender selectedTag]) {
		case 0: protocol = QCCompositionProtocolGraphicAnimation; break;
		case 1: protocol = QCCompositionProtocolImageFilter; break;
		case 2: protocol = QCCompositionProtocolGraphicTransition; break;
	}
	
	/* Update transition mode */
	_transitionMode = ([(NSMatrix*)sender selectedTag] == 2);
	
	/* Unload the current composition on the QCView */
	[qcView unloadComposition];
	[[panel compositionPickerView] setCompositionsFromRepositoryWithProtocol:protocol andAttributes:nil];
	
	/* Make sure the panel is visible in case the user had closed it */
	if(![panel isVisible])
	[panel performSelector:@selector(orderFront:) withObject:nil afterDelay:0.0];
}

- (IBAction) toggleFullScreen:(id)sender
{
	/* Toggle full-screen state */
	if([qcView isInFullScreenMode])
	[qcView exitFullScreenModeWithOptions:nil];
	else
	[qcView enterFullScreenMode:[[NSScreen screens] objectAtIndex:0] withOptions:nil];
}

- (void) _didSelectComposition:(NSNotification*)notification
{
	QCComposition*						composition = [[notification userInfo] objectForKey:@"QCComposition"];
	
	/* Check if a composition is selected in the picker */
	if(composition == nil)
	[qcView unloadComposition];
	else {
		/* Load the newly selected composition in the QCView */
		[qcView stopRendering];
		[qcView loadComposition:composition];
		
		/* If we are displaying a transition, loop the playback time between 0.0 and 1.0 */
		[qcView setLoopTime:(_transitionMode ? 1.0 : 0.0)];
		
		/* Set the values for the image input parameters  */
		if([[qcView inputKeys] containsObject:QCCompositionInputImageKey])
		[qcView setValue:[NSImage imageNamed:@"Source Image"] forInputKey:QCCompositionInputImageKey];
		if([[qcView inputKeys] containsObject:QCCompositionInputSourceImageKey])
		[qcView setValue:[NSImage imageNamed:@"Source Image"] forInputKey:QCCompositionInputSourceImageKey];
		if([[qcView inputKeys] containsObject:QCCompositionInputDestinationImageKey])
		[qcView setValue:[NSImage imageNamed:@"Target Image"] forInputKey:QCCompositionInputDestinationImageKey];
		
		/* Start rendering the composition in the QCView */
		[qcView startRendering];
	}
}

- (void) applicationWillTerminate:(NSNotification*)notification
{
	/* Unregister from composition picker panel notifications */
	[[NSNotificationCenter defaultCenter] removeObserver:self name:QCCompositionPickerPanelDidSelectCompositionNotification object:nil];
}

- (void) windowWillClose:(NSNotification*)notification
{
	/* Quit the application when the window is closed */
	[NSApp terminate:self];
}

@end
