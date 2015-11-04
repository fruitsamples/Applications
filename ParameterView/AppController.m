#import "AppController.h"

@implementation AppController

- (IBAction) compositionChanged:(id) sender
{
	QCComposition*				currentComposition;
	
	/* Retrieve the composition using its name stored in the list, then load the composition in the QCView */
	currentComposition = [_mapNameToComposition objectForKey:[sender titleOfSelectedItem]]; 	
	[qcView loadComposition:currentComposition];
}

- (void) _setupRepositoryEntries
{
	NSInteger index;
	NSArray *selectedCompositions;
	QCComposition *composition;
	NSDictionary *compositionAttributes;
	NSString *compositionName;
	
	/* We just want to retrieve animation compositions */
	selectedCompositions = [[QCCompositionRepository sharedCompositionRepository] compositionsWithProtocols:[NSArray arrayWithObject:QCCompositionProtocolGraphicAnimation] andAttributes:nil];
	
	/* Setup composition pop-up menu */
	[compositionChoice removeAllItems];
	for (index = 0; index < [selectedCompositions count] ; index++) {
		composition = [selectedCompositions objectAtIndex:index];
		compositionAttributes = [composition attributes];
		compositionName = [compositionAttributes objectForKey:QCCompositionAttributeNameKey];
		[compositionChoice addItemWithTitle:compositionName];
		
		/* We map the composition name to the composition instance, thus we can retrieve the composition later */
		[_mapNameToComposition setObject:composition forKey:compositionName];			
	}
}

- (void) dealloc
{
	[_mapNameToComposition release];
	
	[super dealloc];
}

- (void) awakeFromNib
{
	/* Initialize user interface */
	_mapNameToComposition = [[NSMutableDictionary alloc] init];
	[self _setupRepositoryEntries];
	[self compositionChanged:compositionChoice];
	
	/* Start rendering the QCView */
	[qcView startRendering];
}

@end
