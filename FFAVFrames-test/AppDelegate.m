//
//  AppDelegate.m
//  FFAVFrames-test
//
//  Created by Mooncatventures Group on 5/28/12.
//  Copyright (c) 2012 none. All rights reserved.
//

#import "AppDelegate.h"
#import "IRWRTSPCapture.h"
//#import "rtsp_download.h"

#define tmp(x) [NSTemporaryDirectory() stringByAppendingPathComponent:x]
@implementation AppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

static int finished = 0;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
//    self.viewController = [[ViewController alloc] initWithNibName:@"ViewController" bundle:nil];
//    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    //rtsp://89.35.37.82/axis-media/media.amp?resolution=320x240
//    rtsp_download("rtsp://184.72.239.149/vod/mp4://BigBuckBunny_175k.mov", "test.mp4", 20);
    
    IRWRTSPCapture* capture = [[IRWRTSPCapture alloc] init];
    
    NSArray *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [path objectAtIndex:0];

    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDir error:nil];
    
    for (NSString* file in files)
    {
        BOOL ok = [[NSFileManager defaultManager] removeItemAtPath:[documentsDir stringByAppendingPathComponent:file] error:nil];
        if (!ok)
        {
            NSLog(@"remove file failed");
        }
    }
    
    [capture startStreamCaptureFromAddress:@"rtsp://admin:1234@freedom.soft-class.net:2223/ipcam_h264.sdp" toDirectory:documentsDir];
    
    double delayInSeconds = 90;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        capture.shouldStop = YES;
        
        double delayInSeconds = 20.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(),
        ^(void){
        
            NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDir error:nil];
            
            void (^__block concatBlock)();
            
            __block int i = 1;
            concatBlock =
            [^{
                i++;
                if (i<files.count) {
                    NSString* fulllVideo1 = [documentsDir stringByAppendingPathComponent:NSStringF(@"full%d.mp4",i-1)];
                    NSString* fulllVideo2 = [documentsDir stringByAppendingPathComponent:NSStringF(@"full%d.mp4",i)];
                    NSString* fullPath = [documentsDir stringByAppendingPathComponent:files[i]];
                    [IRWRTSPCapture concatenateVideoAtPath:fulllVideo1 withVideo:fullPath toPath:fulllVideo2 onDone:^{
                        concatBlock();
                    }];
                }
            } copy];
            
            NSString* path1 = [documentsDir stringByAppendingPathComponent:files[0]];
            NSString* path2 = [documentsDir stringByAppendingPathComponent:files[1]];
            NSString* fulllVideo1 = [documentsDir stringByAppendingPathComponent:NSStringF(@"full%d.mp4",1)];
            
            [IRWRTSPCapture concatenateVideoAtPath:path1 withVideo:path2 toPath:fulllVideo1 onDone:^{
                concatBlock();
            }];
            
        });
    });
    
//    init_ffmpeg();
//    downloadSegment();
    
    return YES;
}

#if 0
-(void) startRecordingWithFilename:(NSString*)filename
{
    NSLog(@"recording started for filename: %@",filename);
    rtsp_download("", [tmp(filename) UTF8String], 20,
//    rtsp_download("rtsp://a2047.v1412b.c1412.g.vq.akamaistream.net/5/2047/1412/1_h264_350/1a1a1ae555c531960166df4dbc3095c327960d7be756b71b49aa1576e344addb3ead1a497aaedf11/8848125_1_350.mov", [NSStringF(@"%@%@",NSTemporaryDirectory(),filename) UTF8String], 20,
          ^{
              finished++;
              if (finished == 4)
              {
                  finished = 0;
                  void (^onDone)() = ^{
                      finished++;
                      if (finished == 2)
                      {
                          concatenateVideos(tmp(@"file12.mov"), tmp(@"file34.mov"),tmp(@"final.mov"),
                            ^{
                                CMTime lastTime = CMTimeMake(5, 1);
                                for (int i = 0;i<5;i++)
                                {
                                    CMTime interval = CMTimeMake(500, 1000);
                                    CMTimeRange range = CMTimeRangeMake(lastTime,interval);
                                    NSString* cutoutName = tmp(NSStringF(@"cutout-%d-1.mov",i));
                                    cutVideo(tmp(@"final.mov"), range, cutoutName,^{
                                        saveMovieToCameraRoll([cutoutName UTF8String]);
                                    });
                                    lastTime = CMTimeAdd(lastTime, interval);
                                    
                                    interval = CMTimeMake(3000, 1000);
                                    range = CMTimeRangeMake(lastTime,interval);
                                    cutoutName = tmp(NSStringF(@"cutout-%d-2.mov",i));
                                    cutVideo(tmp(@"final.mov"), range, cutoutName,^{
                                        saveMovieToCameraRoll([cutoutName UTF8String]);
                                    });
                                    lastTime = CMTimeAdd(lastTime, interval);
                                    
                                    interval = CMTimeMake(900, 1000);
                                    range = CMTimeRangeMake(lastTime,interval);
                                    cutoutName = tmp(NSStringF(@"cutout-%d-3.mov",i));
                                    cutVideo(tmp(@"final.mov"), range, cutoutName,^{
                                        saveMovieToCameraRoll([cutoutName UTF8String]);
                                    });
                                    lastTime = CMTimeAdd(lastTime, interval);
                                }
                            });
                      }
                  };
                  concatenateVideos(tmp(@"file1.mov"),tmp(@"file2.mov"),tmp(@"file12.mov"),onDone);
//                  concatenateVideos(tmp(@"file1.mov"),tmp(@"file2.mov"),tmp(@"file12.mov"),
//                  ^{
//                      NSLog(@"concatenation finished");
//                      saveMovieToCameraRoll([tmp(@"file12.mov") UTF8String]);
//                  });
                  
                  concatenateVideos(tmp(@"file3.mov"), tmp(@"file4.mov"),tmp(@"file34.mov"),onDone);
              }
          });
}
#endif

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
