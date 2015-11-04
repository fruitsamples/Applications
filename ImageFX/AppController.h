#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

/* We subclass QCView to add drag & drop support */
@interface AppView : QCView
{
	CGImageSourceRef						_sourceRef;
}
@end

@interface AppController : NSObject
{
	IBOutlet NSWindow*						window;
	IBOutlet AppView*						qcView;
	IBOutlet QCCompositionPickerView*		pickerView;
	
	CGImageRef								_imageRef;
}
/* Called from the QCView after a new image file has been dragged */
- (void) setSourceImage:(CGImageRef)imageRef;
@end
