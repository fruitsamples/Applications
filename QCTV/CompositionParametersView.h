#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface CompositionParametersView : NSView
{
	QCRenderer*					_renderer;
	NSMutableArray*				_labels;
	NSMutableArray*				_controls;
	NSSize						_minSize;
}
- (id) initWithRenderer:(QCRenderer*)renderer;
- (NSSize) minimumSize;
- (QCRenderer*) renderer;
- (NSDictionary*) parameters:(BOOL)plistCompatible;
- (void) setParameters:(NSDictionary*)parameters;
@end
