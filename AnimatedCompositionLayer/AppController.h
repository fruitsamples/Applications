#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

/* We use a custom NSView to */
@interface AnimatedView : NSView
@end

/* The application controller class */
@interface AppController : NSObject
{
	IBOutlet NSWindow*						window;
}
@end
