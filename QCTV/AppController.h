#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

#import "FrameReader.h"
#import "FrameCompressor.h"
#import "RenderParametersView.h"

@interface AppController : NSObject
{
	IBOutlet NSWindow*			mainWindow;
	IBOutlet NSView*			renderView;
	IBOutlet NSPanel*			parametersPanel;
	IBOutlet NSView*			resolutionView;
	IBOutlet NSTextField*		widthField;
	IBOutlet NSTextField*		heightField;
	IBOutlet NSView*			exportView;
	IBOutlet NSPopUpButton*		exportMenu;
	
	NSOpenGLContext*			_glContext;
	NSOpenGLPixelFormat*		_glPixelFormat;
	RenderParametersView*		_settingsView;
	FrameReader*				_reader;
	FrameCompressor*			_exporter;
	NSTimer*					_renderTimer;
	NSTimeInterval				_startTime;
#ifndef MAC_OS_X_VERSION_10_5
	BOOL						_resizing;
#endif
}
- (IBAction) updateResolution:(id)sender;
- (IBAction) updateExport:(id)sender;
@end
