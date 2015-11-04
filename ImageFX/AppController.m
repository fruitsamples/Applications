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
	
	/* Get the processed image from the QCView as a CGImageRef and  */
	imageRef = (CGImageRef)[self valueForOutputKey:QCCompositionOutputImageKey ofType:@"CGImage"];
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
	}
	
	return array;
}

@end

@implementation AppController

- (void) applicationDidFinishLaunching:(NSNotification*)notification
{
	/* Configure the composition picker */
	[pickerView setAllowsEmptySelection:YES];
	[pickerView setShowsCompositionNames:YES];
	[pickerView setCompositionsFromRepositoryWithProtocol:QCCompositionProtocolImageFilter andAttributes:nil];
	[pickerView setDrawsBackground:NO];
	
	/* Show the main window */
	[window makeKeyAndOrderFront:nil];
}

- (void) applicationWillTerminate:(NSNotification*)notification
{
	/* Clean up */
	if(_imageRef)
	CGImageRelease(_imageRef);
}

- (void) compositionPickerView:(QCCompositionPickerView*)pickerView didSelectComposition:(QCComposition*)composition
{
	/* Load the selected composition on the QCView and update its image input */
	if([qcView loadComposition:composition]) {
		[qcView setValue:(id)_imageRef forInputKey:QCCompositionInputImageKey];
		[qcView startRendering];
	}
	else
	[qcView stopRendering];
}

- (BOOL) compositionParameterView:(QCCompositionParameterView*)parameterView shouldDisplayParameterWithKey:(NSString*)portKey attributes:(NSDictionary*)portAttributes
{
	/* Make sure the input image parameter is not visible as we are setting it directly */
	return ![portKey isEqualToString:QCCompositionInputImageKey];
}

- (void) windowWillClose:(NSNotification*)notification
{
	[NSApp terminate:self];
}

- (void) setSourceImage:(CGImageRef)imageRef
{
	/* Replace our current image with the new one and update both the composition picker and the QCView */
	if(imageRef != _imageRef) {
		CGImageRelease(_imageRef);
		_imageRef = CGImageRetain(imageRef);
		
		[pickerView setDefaultValue:nil forInputKey:QCCompositionInputImageKey];
		[pickerView setCompositionAspectRatio:NSMakeSize(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef))];
		[pickerView setDefaultValue:(id)imageRef forInputKey:QCCompositionInputImageKey];
		
		if([qcView loadedComposition])
		[qcView setValue:(id)_imageRef forInputKey:QCCompositionInputImageKey];
	}
}

@end
