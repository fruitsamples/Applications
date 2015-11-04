#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

/* User default keys */
#define kUserDefaultKey_CompositionPath			@"compositionPath" //NSString
#define kUserDefaultKey_CompositionParameters	@"compositionParameters" //id (PList compatible)
#define kUserDefaultKey_RenderWidth				@"renderWidth" //NSInteger
#define kUserDefaultKey_RenderHeight			@"renderHeight" //NSInteger
#define kUserDefaultKey_RenderPeriod			@"renderPeriod" //NSInteger

/* Customized application class */
@interface Application : NSApplication
{
	IBOutlet NSMenu*						contextualMenu;
	IBOutlet NSWindow*						dimensionsWindow;
	IBOutlet NSWindow*						parametersWindow;
	IBOutlet QCCompositionParameterView*	parametersView;
	
	NSWindow*								_window;
	NSOpenGLContext*						_glContext;
	NSOpenGLPixelFormat*					_glFormat;
	QCRenderer*								_renderer;
	BOOL									_hasURLPort;
	NSTimer*								_timer;
	NSTimeInterval							_startTime;
}
@end

/* Customized window view */
@interface ApplicationView : NSView
@end
