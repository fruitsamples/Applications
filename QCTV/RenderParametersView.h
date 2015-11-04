#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface RenderParametersView : NSView
{
	NSMutableArray*					_renderers;
	NSSize							_bestSize;
}
- (void) addRenderer:(QCRenderer*)renderer title:(NSString*)title;
- (void) removeRenderer:(QCRenderer*)renderer;
- (void) removeAllRenderers;
- (NSArray*) renderers;
- (NSSize) bestSize;
- (NSDictionary*) parameters:(BOOL)plistCompatible;
- (void) setParameters:(NSDictionary*)parameters;
@end
