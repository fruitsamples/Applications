#import <Cocoa/Cocoa.h>
#import <QuickTime/QuickTime.h>

int main(int argc, char* argv[])
{
    /* We need to initialize QuickTime */
	EnterMovies();
	
	return NSApplicationMain(argc, (const char**)argv);
}
