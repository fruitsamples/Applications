#import "AppController.h"

@implementation AppView

/* We override this method to know whenever the composition is rendered in the QCView */
- (BOOL) renderAtTime:(NSTimeInterval)time arguments:(NSDictionary*)arguments
{
	id										image;
	
	/* Call super so that rendering happens */
	if(![super renderAtTime:time arguments:arguments])
	return NO;
	
	/* Retrieve the current video input image from the "videoImage" output of the composition then use it as a default image for the Composition Picker panel
		Because we pass the image from one Quartz Composer object to another one, we can use the optimized QCImage type
	*/
	if(image = [self valueForOutputKey:@"videoImage" ofType:@"QCImage"])
	[[[QCCompositionPickerPanel sharedCompositionPickerPanel] compositionPickerView] setDefaultValue:image forInputKey:QCCompositionInputImageKey];
	
	return YES;
}

@end

@implementation AppController

- (void) _didSelectComposition:(NSNotification*)notification
{
	QCComposition*						composition = [[notification userInfo] objectForKey:@"QCComposition"];
	
	/* Set the identifier of the selected composition on the "compositionIdentifier" input of the composition,
		which passes it in turn to a Composition Loader patch which loads the composition and applies it to the video input */
	[qcView setValue:[composition identifier] forInputKey:@"compositionIdentifier"];
}

- (void) applicationDidFinishLaunching:(NSNotification*)notification
{
	QCCompositionPickerPanel*				pickerPanel = [QCCompositionPickerPanel sharedCompositionPickerPanel];
	
	/* Load our composition file on the QCView and start rendering */
	if(![qcView loadCompositionFromFile:[[NSBundle mainBundle] pathForResource:@"Composition" ofType:@"qtz"]])
	[NSApp terminate:nil];
	[qcView startRendering];
	
	/* Configure and show the Composition Picker panel */
	[[pickerPanel compositionPickerView] setAllowsEmptySelection:YES];
	[[pickerPanel compositionPickerView] setShowsCompositionNames:YES];
	[[pickerPanel compositionPickerView] setCompositionsFromRepositoryWithProtocol:QCCompositionProtocolImageFilter andAttributes:nil];
	[pickerPanel orderFront:nil];
	
	/* Register for composition picker panel notifications */
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didSelectComposition:) name:QCCompositionPickerPanelDidSelectCompositionNotification object:nil];
}

- (void) applicationWillTerminate:(NSNotification*)notification
{
	/* Unregister from composition picker panel notifications */
	[[NSNotificationCenter defaultCenter] removeObserver:self name:QCCompositionPickerPanelDidSelectCompositionNotification object:nil];
}

- (void) windowWillClose:(NSNotification*)notification
{
	[NSApp terminate:self];
}

- (IBAction) toggleCompositionPicker:(id)sender
{
	QCCompositionPickerPanel*				pickerPanel = [QCCompositionPickerPanel sharedCompositionPickerPanel];
	
	/* Toggle the Composition Picker panel visibility */
	if([pickerPanel isVisible])
	[pickerPanel orderOut:sender];
	else
	[pickerPanel orderFront:sender];
}

- (IBAction) savePNG:(id)sender
{
	NSSavePanel*							savePanel = [NSSavePanel savePanel];
	CGImageRef								imageRef;
	CGImageDestinationRef					destinationRef;
	
	/* Display the save panel */
	[savePanel setRequiredFileType:@"png"];
	if([savePanel runModalForDirectory:nil file:@"My Picture"] == NSFileHandlingPanelOKButton) {
		/* Grab the current contents of the QCView as a CGImageRef and use ImageIO to save it as a PNG file */
		if(imageRef = (CGImageRef)[qcView createSnapshotImageOfType:@"CGImage"]) {
			if(destinationRef = CGImageDestinationCreateWithURL((CFURLRef)[NSURL fileURLWithPath:[savePanel filename]], kUTTypePNG, 1, NULL)) {
				CGImageDestinationAddImage(destinationRef, imageRef, NULL);
				if(!CGImageDestinationFinalize(destinationRef))
				NSBeep();
				CFRelease(destinationRef);
			}
			else
			NSBeep();
			CGImageRelease(imageRef);
		}
		else
		NSBeep();
	} 
}

@end
