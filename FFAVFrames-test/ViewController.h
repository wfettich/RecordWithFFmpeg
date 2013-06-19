/* copyright Mooncatventures group 2012
 This is a test of the latest version of FFPlayer.framework
 This code is in the public domain, do as you wish
 Code is roughly based on VTMscreenRecorder from Subsequently and Furthermore */


#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <FFPlayer/Frames.h>

@interface ViewController : UIViewController<CGImageBufferDelegate> {
    NSTimer *clockTimer;
	NSTimer *assetWriterTimer;
	AVMutableComposition *mutableComposition;
	AVAssetWriter *assetWriter;
	AVAssetWriterInput *assetWriterInput;
	AVAssetWriterInputPixelBufferAdaptor *assetWriterPixelBufferAdaptor;
	CFAbsoluteTime firstFrameWallClockTime;
    NSURL *movieURL;
    IBOutlet UIImageView *imageView;
    Frames *video;
	NSTimer* iTimer;
    BOOL startSampleing;
    
}

@property (nonatomic,assign) IBOutlet UIButton *startStopButton;
@property (nonatomic,assign) IBOutlet UIImageView *imageView;
@property (nonatomic,strong) Frames *video;
//-(void)displayNextFrame:(NSTimer *)timer;
-(IBAction) handleStartStopTapped: (id) sender;
- (void)saveMovieToCameraRoll;
-(void) writeSample;

@end
