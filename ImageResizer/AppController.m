#import "AppController.h"

@implementation AppView

- (id) initWithCoder:(NSCoder*)decoder
{
	/* Register for drag & drop */
	if(self = [super initWithCoder:decoder])
	[self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
	
	return self;
}

- (NSDragOperation) draggingEntered:(id<NSDraggingInfo>)sender
{
	NSPasteboard*				pasteboard = [sender draggingPasteboard];
	CGImageSourceRef			sourceRef;
	
	/* Check if the dragged file is valid by creating an ImageIO source with it */
	if([[pasteboard types] containsObject:NSFilenamesPboardType]) {
		if(_sourceRef = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:[[pasteboard propertyListForType:NSFilenamesPboardType] objectAtIndex:0]], NULL))
		return NSDragOperationCopy;
	}
	
	return NSDragOperationNone;
}

- (void) draggingExited:(id<NSDraggingInfo>)sender
{
	/* Destroy ImageIO source */
	if(_sourceRef) {
		CFRelease(_sourceRef);
		_sourceRef = NULL;
	}
}

- (BOOL) performDragOperation:(id<NSDraggingInfo>)sender
{
	CGImageRef					imageRef;
	
	/* Create the image from the dragged file and update our application controller */
	if(_sourceRef) {
		if(imageRef = CGImageSourceCreateImageAtIndex(_sourceRef, 0, NULL)) {
			[(AppController*)[NSApp delegate] setSourceImage:imageRef];
			CGImageRelease(imageRef);
		}
		CFRelease(_sourceRef);
		_sourceRef = NULL;
		return (imageRef ? YES : NO);
	}
	
	return NO;
}

- (void) mouseDown:(NSEvent*)event
{
	NSPoint						point = [self convertPoint:[event locationInWindow] fromView:nil];
	
	/* Start drag & drop */
	if([self loadedComposition])
	[self dragPromisedFilesOfTypes:[NSArray arrayWithObject:@"png"] fromRect:NSMakeRect(point.x - 16, point.y - 16, 32, 32) source:self slideBack:YES event:event];
}

- (NSArray*) namesOfPromisedFilesDroppedAtDestination:(NSURL*)dropDestination
{
	unsigned					index = 0;
	NSArray*					array = nil;
	CGImageRef					imageRef;
	CGImageDestinationRef		destinationRef;
	NSString*					name;
	
	/* Make sure we are dragging to a file */
	if(![dropDestination isFileURL])
	return nil;
	
	/* Get the resized image from our application controller */
	imageRef = [(AppController*)[NSApp delegate] getResizedImage];
	if(imageRef == NULL)
	return nil;
	
	/* Generate a unique file name */
	do {
		index += 1;
		name = [NSString stringWithFormat:@"Image-%i.png", index];
	} while([[NSFileManager defaultManager] fileExistsAtPath:[[NSURL URLWithString:name relativeToURL:dropDestination] path]]);
	
	/* Save the CGImageRef as a PNG file using ImageIO */
	if(destinationRef = CGImageDestinationCreateWithURL((CFURLRef)[NSURL URLWithString:name relativeToURL:dropDestination], kUTTypePNG, 1, NULL)) {
		CGImageDestinationAddImage(destinationRef, imageRef, NULL);
		if(CGImageDestinationFinalize(destinationRef))
		array = [NSArray arrayWithObject:name];
		CFRelease(destinationRef);
	}
	
	return array;
}

@end

@implementation AppController

- (void) applicationDidFinishLaunching:(NSNotification*)notification
{
	/* Load the preview composition on the QCView */
	[qcView loadCompositionFromFile:[[NSBundle mainBundle] pathForResource:@"Composition" ofType:@"qtz"]];
	[qcView startRendering];
}

- (void) applicationWillTerminate:(NSNotification*)notification
{
	/* Clean up */
	if(_imageRef)
	CGImageRelease(_imageRef);
	if(_renderer)
	[_renderer release];
}

- (void) windowWillClose:(NSNotification*)notification
{
	/* Terminate the application */
	[NSApp terminate:self];
}

- (BOOL) compositionParameterView:(QCCompositionParameterView*)parameterView shouldDisplayParameterWithKey:(NSString*)portKey attributes:(NSDictionary*)portAttributes
{
	/* Make sure the input image parameter is not visible as we are setting it directly */
	return ![portKey isEqualToString:QCCompositionInputImageKey];
}

- (void) compositionParameterView:(QCCompositionParameterView*)parameterView didChangeParameterWithKey:(NSString*)portKey
{
	/* Since one of the parameter has changed, we need to re-renderer the QCRenderer */
	if(![_renderer renderAtTime:0.0 arguments:nil])
	NSLog(@"QCRenderer failed rendering");
	
	/* Forward the image produced by the QCRenderer to the preview composition on the QCView */
	[qcView setValue:[_renderer valueForOutputKey:QCCompositionOutputImageKey ofType:@"QCImage"] forInputKey:@"inImage"];
}

- (void) setSourceImage:(CGImageRef)imageRef
{
	static CGColorSpaceRef				deviceRGBColorSpace = NULL;
	QCComposition*						composition = [[QCCompositionRepository sharedCompositionRepository] compositionWithIdentifier:@"/image resizer"];
	CGColorSpaceRef						colorSpace;
	
	/* Keep around DeviceRGB colorspace */
	if(deviceRGBColorSpace == NULL)
	deviceRGBColorSpace = CGColorSpaceCreateDeviceRGB();
	
	/* Replace our current image with the new one and re-create the QCRenderer */
	if(imageRef != _imageRef) {
		CGImageRelease(_imageRef);
		_imageRef = CGImageRetain(imageRef);
		
		/* Compute colorspace to use for the QCRenderer (use the one from the source image if possible - Quartz Composer cannot render in gray or device colorspaces) */
		colorSpace = CGImageGetColorSpace(imageRef);
		if((CGColorSpaceGetModel(colorSpace) != kCGColorSpaceModelRGB) || CFEqual(colorSpace, deviceRGBColorSpace))
		colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
		else
		colorSpace = CGColorSpaceRetain(colorSpace);
		
		/* Re-create QCRenderer and set source image */
		[_renderer release];
		_renderer = [[QCRenderer alloc] initWithComposition:composition colorSpace:colorSpace];
		[_renderer setValue:(id)_imageRef forInputKey:QCCompositionInputImageKey];
		[paramView setCompositionRenderer:_renderer];
		
		/* We don't need the colorspace anymore */
		CGColorSpaceRelease(colorSpace);
		
		/* Force-update the preview composition in the QCView */
		[self compositionParameterView:nil didChangeParameterWithKey:nil];
	}
}

- (CGImageRef) getResizedImage
{
	return (CGImageRef)[_renderer valueForOutputKey:QCCompositionOutputImageKey ofType:@"CGImage"];
}

@end
