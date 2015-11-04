#import <stdlib.h>

#import "AppController.h"

@implementation AnimatedView

- (void) mouseDown:(NSEvent*) event
{
	/* Animate composition parameters "size" and "primary color" through a Core Animation transaction of 1 second duration */
	[CATransaction begin];
		[CATransaction setValue:[NSNumber numberWithFloat:1] forKey:kCATransactionAnimationDuration];
		[[self layer] setValue:[NSNumber numberWithFloat:drand48()] forKeyPath:@"patch.size.value"];
		[[self layer] setValue:[(id)CGColorCreateGenericRGB(drand48(), drand48(), drand48(), 1.0) autorelease] forKeyPath:[NSString stringWithFormat:@"patch.%@.value",QCCompositionInputPrimaryColorKey]];
	[CATransaction commit];
}

@end

@implementation AppController

- (void) applicationDidFinishLaunching:(NSNotification*)notification
{
	QCComposition*				composition;
	AnimatedView*				view;
	
	/* Get a composition from the repository */
	composition = [[QCCompositionRepository sharedCompositionRepository] compositionWithIdentifier:@"/defocus"];
	if(composition == nil)
	[NSApp terminate:nil];
	
	/* Configure the content view of the window to use a Core Animation layer */
	view = [[AnimatedView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
	[view setWantsLayer:YES];
	[view setLayer:[QCCompositionLayer compositionLayerWithComposition:composition]];
	[window setContentView:view];
	[view release];
	
	/* Show window */
	[window makeKeyAndOrderFront:nil];
}

- (void) windowWillClose:(NSNotification*)notification
{
	[NSApp terminate:nil];
}

@end
