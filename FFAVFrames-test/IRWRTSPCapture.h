//
//  IRWRTSPCapture.h
//  iRewind
//
//  Created by Walter Fettich on 10.07.13.
//  Copyright (c) 2013 i-Rewind SRL. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

void init_ffmpeg();
int rtsp_download(const char * url_address, const char * save_path, int duration, void (^onComplete)(void));

@interface IRWRTSPCapture : NSObject
{
}
@property (nonatomic,assign) BOOL shouldStop;

-(void) startCaptureFromAddress:(NSString*)url_address toTempFile:(NSString *)save_path forSeconds:(int)duration withFinishedBlock:(void (^)(BOOL,CFAbsoluteTime,NSString*))onComplete;
-(void) startStreamCaptureFromAddress:(NSString*)url_address toDirectory:(NSString *)save_path;
+(void) concatenateVideoAtPath:(NSString*) file1 withVideo:(NSString*)file2 toPath:( NSString*) outputPath onDone:(void (^)(void))onComplete;
+(void) saveMovieToCameraRoll:(NSString*) filepath;
+(void) cutVideoAtPath:(NSString*)file1 inRange:(CMTimeRange)cutRange toPath:(NSString*) outputPath onDone:(void (^)(void))onComplete;

@end
