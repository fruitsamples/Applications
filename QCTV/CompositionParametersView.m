#import "CompositionParametersView.h"

#define kVOffset				8
#define kHMargin				10
#define kVMargin				10
#define kHSeparator				10
#define kDefaultWidth			150

static NSString* _StringFromColor(NSColor* color)
{
	float					components[4];
	
	//Convert color to standard colorspace & Create string from R, G, B and A values
	color = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
	[color getComponents:components];
	
	return (color ? [NSString stringWithFormat:@"R=%g G=%g B=%g A=%g", components[0], components[1], components[2], components[3]] : nil);
}

static NSColor* _ColorFromString(NSString* string)
{
	NSScanner*				scanner = [NSScanner scannerWithString:string];
	float					components[4];
	
	//Extract R, G, B and A values from string
	[scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"RGBA= "]];
	[scanner scanFloat:&components[0]];
	[scanner scanFloat:&components[1]];
	[scanner scanFloat:&components[2]];
	[scanner scanFloat:&components[3]];
	
	return (scanner ? [NSColor colorWithColorSpace:[NSColorSpace genericRGBColorSpace] components:components count:4] : nil);
}

@implementation CompositionParametersView

- (id) initWithFrame:(NSRect)frameRect
{
	//Call designated initializer
	return [self initWithRenderer:nil];
}

- (id) initWithRenderer:(QCRenderer*)renderer
{
#ifdef MAC_OS_X_VERSION_10_5
	static NSMutableDictionary*	options = nil;
#endif
	NSArray*					inputList = [renderer inputKeys];
	float						maxLabelWidth = 0,
								maxControlWidth = 0,
								totalHeight = 0;
	unsigned					i;
	NSString*					inputKey;
	NSDictionary*				inputAttributes;
	NSString*					type;
	NSTextField*				label;
	NSControl*					control;
	NSNumberFormatter*			formatter;
	float						width;
	NSNumber*					minNumber;
	NSNumber*					maxNumber;
	
	//Iterate through all renderer inputs
	_labels = [NSMutableArray new];
	_controls = [NSMutableArray new];
	for(i = 0; i < [inputList count]; ++i) {
		inputKey = [inputList objectAtIndex:i];
		inputAttributes = [[renderer attributes] objectForKey:inputKey];
		type = [inputAttributes objectForKey:QCPortAttributeTypeKey];
		
		//Create a label text field for the input
		label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, kVOffset + totalHeight, kDefaultWidth, 14)];
		[[label cell] setControlSize:NSSmallControlSize]; //FIXME: appears to be useless
		[[label cell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		[[label cell] setLineBreakMode:NSLineBreakByTruncatingTail];
		[label setStringValue:([inputAttributes objectForKey:QCPortAttributeNameKey] ? [inputAttributes objectForKey:QCPortAttributeNameKey] : inputKey)];
		[label setEditable:NO];
		[label setSelectable:NO];
		[label setBezeled:NO];
		[label setDrawsBackground:NO];
		[label setAlignment:NSRightTextAlignment];
		[label sizeToFit];
		
		//Create a control of the appropriate type for the input
		if([type isEqualToString:QCPortTypeBoolean]) {
			control = [[NSButton alloc] initWithFrame:NSMakeRect(-2, kVOffset + totalHeight - 2, 20, 16)];
			[(NSButton*)control setButtonType:NSSwitchButton];
			[(NSButton*)control setTitle:nil];
			[[control cell] setControlSize:NSSmallControlSize];
			[control sizeToFit];
			totalHeight += 25;
		}
		else if([type isEqualToString:QCPortTypeIndex]) {
			control = [[NSTextField alloc] initWithFrame:NSMakeRect(0, kVOffset + totalHeight - 3, kDefaultWidth, 19)];
			[[control cell] setWraps:NO];
			[[control cell] setScrollable:YES];
			[[control cell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
			formatter = [NSNumberFormatter new];
			[formatter setAllowsFloats:NO];
			[formatter setMinimum:[inputAttributes objectForKey:QCPortAttributeMinimumValueKey]];
			[formatter setMaximum:[inputAttributes objectForKey:QCPortAttributeMaximumValueKey]];
			[[control cell] setFormatter:formatter];
			[formatter release];
			[control setAutoresizingMask:NSViewWidthSizable];
			totalHeight += 25;
		}
		else if([type isEqualToString:QCPortTypeNumber]) {
			minNumber = [inputAttributes objectForKey:QCPortAttributeMinimumValueKey];
			maxNumber = [inputAttributes objectForKey:QCPortAttributeMaximumValueKey];
			if(minNumber && maxNumber) {
				control = [[NSSlider alloc] initWithFrame:NSMakeRect(0, kVOffset + totalHeight, kDefaultWidth, 15)];
				[[control cell] setControlSize:NSSmallControlSize];
				[(NSSlider*)control setMinValue:[minNumber doubleValue]];
				[(NSSlider*)control setMaxValue:[maxNumber doubleValue]];
			}
			else {
				control = [[NSTextField alloc] initWithFrame:NSMakeRect(0, kVOffset + totalHeight - 3, kDefaultWidth, 19)];
				[[control cell] setWraps:NO];
				[[control cell] setScrollable:YES];
				[[control cell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
				formatter = [NSNumberFormatter new];
				[formatter setMinimum:minNumber];
				[formatter setMaximum:maxNumber];
				[[control cell] setFormatter:formatter];
				[formatter release];
				[[control cell] setSendsActionOnEndEditing:YES];
			}
			[control setAutoresizingMask:NSViewWidthSizable];
			totalHeight += 25;
		}
		else if([type isEqualToString:QCPortTypeString]) {
			control = [[NSTextField alloc] initWithFrame:NSMakeRect(0, kVOffset + totalHeight - 3, kDefaultWidth, 33)];
			[[control cell] setWraps:YES];
			[[control cell] setScrollable:NO];
			[[control cell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
			[[control cell] setSendsActionOnEndEditing:YES];
			[control setAutoresizingMask:NSViewWidthSizable];
			totalHeight += 40;
		}
		else if([type isEqualToString:QCPortTypeColor]) {
			control = [[NSColorWell alloc] initWithFrame:NSMakeRect(0, kVOffset + totalHeight - 3, 50, 20)];
			totalHeight += 25;
		}
		else if([type isEqualToString:QCPortTypeImage]) {
			control = [[NSImageView alloc] initWithFrame:NSMakeRect(0, kVOffset + totalHeight - 2, 70, 70)];
			[(NSImageView*)control setEditable:YES];
			[(NSImageView*)control setImageFrameStyle:NSImageFrameGroove];
			totalHeight += 76;
		}
		else /* QCPortTypeStructure */
		control = nil;
		
		//Check if we were able to create a control for that input
		if(control) {
			//Update the maximum label width
			width = [label frame].size.width;
			if(width > maxLabelWidth)
			maxLabelWidth = width;
			
			//Update the control label width
			width = [control frame].size.width;
			if(width > maxControlWidth)
			maxControlWidth = width;
			
			//Add label to label list
			[_labels addObject:label];
			
			//Finish configuring control and add it to control list
#ifndef MAC_OS_X_VERSION_10_5
			if([control isKindOfClass:[NSColorWell class]])
			[(NSColorWell*)control setColor:[renderer valueForInputKey:inputKey]];
			else
			[control setObjectValue:[renderer valueForInputKey:inputKey]];
#endif
			[control setTag:i];
#ifdef MAC_OS_X_VERSION_10_5
			if(options == nil) {
				options = [NSMutableDictionary new];
				[options setObject:[NSNumber numberWithBool:NO] forKey:@"NSConditionallySetsEnabled"];
				[options setObject:[NSNumber numberWithBool:NO] forKey:@"NSRaisesForNotApplicableKeys"];
			}
			[control bind:@"value" toObject:renderer withKeyPath:[NSString stringWithFormat:@"patch.%@.value", inputKey] options:options];
#else
			[control setTarget:self];
			[control setAction:@selector(_controlAction:)];
#endif
			[_controls addObject:control];
			[control release];
		}
		[label release];
	}
	
	//Compute the minimal view size so that all labels and controls fit
	if(totalHeight > 0) {
		_minSize.width = kHMargin + maxLabelWidth + kHSeparator + maxControlWidth + kHMargin;
		_minSize.height = kVMargin + totalHeight + kVMargin;
	}
	
	//Initialize view
	if(self = [super initWithFrame:NSMakeRect(0, 0, _minSize.width, _minSize.height)]) {
		//Keep renderer around
		_renderer = [renderer retain];
		
		//Add labels and controls subviews from their respective lists
		for(i = 0; i < [_labels count]; ++i) {
			label = [_labels objectAtIndex:i];
			[label setFrameOrigin:NSMakePoint(kHMargin, kVMargin + [label frame].origin.y)];
			[self addSubview:label];
		}
		for(i = 0; i < [_controls count]; ++i) {
			control = [_controls objectAtIndex:i];
			[control setFrameOrigin:NSMakePoint(kHMargin + maxLabelWidth + kHSeparator, kVMargin + [control frame].origin.y)];
			[self addSubview:control];
		}
	}
	
	return self;
}

- (void) dealloc
{
#ifdef MAC_OS_X_VERSION_10_5
	unsigned				i;
#endif

	//Release the controls and renderer
#ifdef MAC_OS_X_VERSION_10_5
	for(i = 0; i < [_controls count]; ++i)
	[(NSControl*)[_controls objectAtIndex:i] unbind:@"value"];
#endif
	[_labels release];
	[_controls release];
	[_renderer release];
	
	[super dealloc];
}

- (BOOL) isFlipped
{
	return YES;
}

#ifndef MAC_OS_X_VERSION_10_5

- (void) _controlAction:(id)sender
{
	NSString*				inputKey;
	
	//Retrieve the renderer input key from the control tag
	inputKey = [[_renderer inputKeys] objectAtIndex:[(NSControl*)sender tag]];
	
	//Simply forward the current control value to the renderer input
	[_renderer setValue:([sender isKindOfClass:[NSColorWell class]] ? [(NSColorWell*)sender color] : [(NSControl*)sender objectValue]) forInputKey:inputKey];
	
	//Update control value to be synchronized with final renderer input value
	if([sender isKindOfClass:[NSColorWell class]])
	[(NSColorWell*)sender setColor:[_renderer valueForInputKey:inputKey]];
	else
	[(NSControl*)sender setObjectValue:[_renderer valueForInputKey:inputKey]];
}

#endif

- (NSSize) minimumSize
{
	return _minSize;
}

- (QCRenderer*) renderer
{
	return _renderer;
}

- (NSDictionary*) parameters:(BOOL)plistCompatible
{
	NSMutableDictionary*	dictionary = [NSMutableDictionary dictionary];
	unsigned				i;
	NSString*				inputKey;
	id						value;
	
	//Iterate through all editable renderer inputs
	for(i = 0; i < [_controls count]; ++i) {
		inputKey = [[_renderer inputKeys] objectAtIndex:[(NSControl*)[_controls objectAtIndex:i] tag]];
		value = [_renderer valueForInputKey:inputKey];
		
		//Convert current input value to a PList compatible object
		if(plistCompatible) {
			if([value isKindOfClass:[NSColor class]])
			value = _StringFromColor((NSColor*)value);
			else if([value isKindOfClass:[NSImage class]])
			value = [(NSImage*)value TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];
			else if(![value isKindOfClass:[NSNumber class]] && ![value isKindOfClass:[NSString class]])
			value = nil;
		}
		
		//Add object to parameters dictionary
		if(value)
		[dictionary setObject:value forKey:inputKey];
	}
	
	return dictionary;
}

- (void) setParameters:(NSDictionary*)parameters
{
	unsigned				i;
	NSString*				inputKey;
	NSString*				inputType;
	id						value;
#ifndef MAC_OS_X_VERSION_10_5
	CGImageSourceRef		sourceRef;
#endif
	NSControl*				control;
	
	//Iterate through all editable renderer inputs
	for(i = 0; i < [_controls count]; ++i) {
		control = [_controls objectAtIndex:i];
		inputKey = [[_renderer inputKeys] objectAtIndex:[control tag]];
		inputType = [[[_renderer attributes] objectForKey:inputKey] objectForKey:QCPortAttributeTypeKey];
		value = [parameters objectForKey:inputKey];
		if(value) {
			//Convert PList compatible object back to value
			if([inputType isEqualToString:QCPortTypeImage] && [value isKindOfClass:[NSData class]]) {
#ifdef MAC_OS_X_VERSION_10_5
				value = [[[NSImage alloc] initWithData:value] autorelease];
#else
				/*
					There is a bug in Quartz Composer on Mac OS X 10.4 when passing a NSImage that can cause its color profile
					information to be lost, leading to hue shifting in the image's pixels. This is especially visible when
					passing / retrieving an image several times to a Quartz Composer composition.
					The workaround is to pass a CGImageRef created with ImageIO instead of an NSImage.
				*/
				sourceRef = CGImageSourceCreateWithData((CFDataRef)value, NULL);
				if(sourceRef) {
					value = [(id)CGImageSourceCreateImageAtIndex(sourceRef, 0, NULL) autorelease];
					CFRelease(sourceRef);
				}
				else
				value = nil;
#endif
			}
			else if([inputType isEqualToString:QCPortTypeColor] && [value isKindOfClass:[NSString class]])
			value = _ColorFromString(value);
		}
		
		//Set input value
		[_renderer setValue:value forInputKey:inputKey];
		
#ifndef MAC_OS_X_VERSION_10_5
		//Update control
		if([control isKindOfClass:[NSColorWell class]])
		[(NSColorWell*)control setColor:[_renderer valueForInputKey:inputKey]];
		else
		[control setObjectValue:[_renderer valueForInputKey:inputKey]];
#endif
	}
}

@end
