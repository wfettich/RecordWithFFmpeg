//
//  IRWRTSPCapture.m
//  iRewind
//
//  Created by Walter Fettich on 10.07.13.
//  Copyright (c) 2013 i-Rewind SRL. All rights reserved.
//

#include "libavutil/avutil.h"
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"

#import "IRWRTSPCapture.h"
#import <AssetsLibrary/AssetsLibrary.h>

#define DDLogError NSLog

//static int ddLogLevel = LOG_LEVEL_INFO;

#define LOG_ERR_AND_EXIT(err,func) \
if( err < 0) \
{\
char errbuf[400]; \
av_strerror(err,errbuf,400); \
NSLog(@"%s failed with error %s",func,errbuf); \
return EXIT_FAILURE; \
}

#define LOG_ERR(err,func) \
if( err < 0) \
{\
char errbuf[400]; \
av_strerror(err,errbuf,400); \
NSLog(@"%s failed with error %s",func,errbuf); \
}

static NSObject* lock;
static NSLock* streamCaptureLock;

int open_input_context(AVFormatContext** input_context,const char * url_address);
int init_stream_copy(AVFormatContext *oc, AVCodecContext *codec, AVStream *ost, AVCodecContext *icodec, AVStream *ist);

@interface IRWRTSPCapture ()
@property (nonatomic,assign) dispatch_queue_t callerQueue;

@end

@implementation IRWRTSPCapture

-(IRWRTSPCapture*) init
{
    if (self = [super init])
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            lock = [[NSObject alloc] init];
            streamCaptureLock = [[NSLock alloc] init];
            init_ffmpeg();
        });
    }
    return self;
}

void init_ffmpeg()
{    
    av_register_all();
    avformat_network_init();
}

-(void) startStreamCaptureFromAddress:(NSString*)url_address toDirectory:(NSString *)save_path 
{
    //recursive blocks muhahhaha http://ddeville.me/2011/10/recursive-blocks-objc/
    
    //TODO WF
    void (^__block doneBlock)(BOOL,CFAbsoluteTime,NSString*);
    void (^__block startCaptureBlock)();
    
    NSString* tempFilepath = [save_path stringByAppendingPathComponent:@"temp.mp4"];

    startCaptureBlock = [^void ()
    {
        [self startCaptureFromAddress:url_address toTempFile:tempFilepath forSeconds:15 withFinishedBlock:doneBlock];
    } copy];
    
    doneBlock = [^void (BOOL success, CFAbsoluteTime start_time, NSString* tempFilename)
    {        
        if (success)
        {
            NSLog(@"recording finished");
            //TODO rename file with start time
            NSString* newFilename = save_path;
            newFilename = [newFilename stringByAppendingPathComponent:NSStringF(@"%d.mp4",(int)start_time)];
            NSLog(@"rename file %@ with %@",tempFilename, newFilename);
            BOOL ok = [[NSFileManager defaultManager] moveItemAtPath:tempFilename toPath:newFilename error:nil];
            if (ok)
                NSLog(@"move succeeded");
            else
                NSLog(@"move failed");
        }
        else
        {
            //TODO delete file if it exists            
        }
        
        if (success && NO == self.shouldStop)
        {
        }
        else
        {
            NSLog(@"stream capture should stop");
        }
    } copy];
    
    startCaptureBlock();
}

-(void) startCaptureFromAddress:(NSString*)url_address toTempFile:(NSString *)save_path forSeconds:(int)duration withFinishedBlock:(void (^)(BOOL,CFAbsoluteTime,NSString*))onComplete
{
    self.callerQueue = dispatch_get_current_queue();
    NSArray* params = [NSArray arrayWithObjects:url_address,save_path,@(duration),onComplete, nil];
    
    [NSThread detachNewThreadSelector:@selector(downloadWithParams:) toTarget:self withObject:params];
}

-(int) downloadWithParams:(NSArray*)params
{
    if (params.count > 2)
    {
        void (^finishedBlock)(BOOL,CFAbsoluteTime,NSString*) = nil;
        NSString* url = params[0];
        NSString* save_path = params[1];
        NSNumber* duration = params[2];
        if (params.count > 3)
        {
            finishedBlock = params[3];
        }
        
        return [self downloadFromURL:url withTempFilepath:save_path forSeconds:[duration intValue] withFinishedBlock:finishedBlock];
    }
    else
    {
        DDLogError(@"[%@] not enough parameters for downloadFromURL",_classStr);
        return EXIT_FAILURE;
    }
}

int init_output_context(AVFormatContext** p_output_context,
                        AVOutputFormat** p_output_format,
                        AVStream** p_output_video_stream,
                        AVStream* input_video_stream,
                        NSString* save_path)
{
    avformat_alloc_output_context2(p_output_context, NULL, NULL, [save_path UTF8String]);
        
    if(!*p_output_context)
    {
        NSLog(@"Could not deduce output format from file extension");
        return EXIT_FAILURE;
    }
    *p_output_format = (*p_output_context)->oformat;
    
    if((*p_output_format)->video_codec != AV_CODEC_ID_NONE)
    {
        *p_output_video_stream = avformat_new_stream((*p_output_context), input_video_stream->codec->codec);
        if((*p_output_format)->flags & AVFMT_GLOBALHEADER)
            (*p_output_video_stream)->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
    }
    
    int err = init_stream_copy(*p_output_context, (*p_output_video_stream)->codec, *p_output_video_stream,
                               input_video_stream->codec, input_video_stream);
    
    LOG_ERR_AND_EXIT(err, "init_stream_copy");
        
    err = avio_open(&(*p_output_context)->pb, [save_path UTF8String], AVIO_FLAG_WRITE);
    LOG_ERR_AND_EXIT(err, "avio_open");
    
    err = avformat_write_header(*p_output_context, NULL);
    LOG_ERR_AND_EXIT(err, "avformat_write_header");
 
    return EXIT_SUCCESS;
}

-(int) downloadFromURL:(NSString*)url_address withTempFilepath:(NSString *)save_path forSeconds:(int)duration withFinishedBlock:(void (^)(BOOL,CFAbsoluteTime start_time,NSString* filename))onComplete
{
    //    NSLog(@"ffmpeg version %s",LIBAVFORMAT_IDENT);
    //    const char* build_conf = avformat_configuration();
    //    NSLog(@"ffmpeg build conf %s",build_conf);
    
    NSLog(@"start new capture");
    AVFormatContext* input_context = NULL;
    
    int err = open_input_context(&input_context,[url_address UTF8String]);

    if (err == EXIT_FAILURE || input_context == 0)
    {
        NSLog(@"input_context is invalid");
        dispatch_async(self.callerQueue, ^{
            if (onComplete) onComplete(NO,0,nil);
        });
        return EXIT_FAILURE;
    }

    AVStream *input_video_stream = NULL;
    int video_stream_index = -1;
    
    if(! input_context)
    {
        NSLog(@"input_context is nil");
        dispatch_async(self.callerQueue, ^{
            if (onComplete) onComplete(NO,0,nil);
        });
        return EXIT_FAILURE;
    }
    
    for(unsigned int i = 0; i < input_context->nb_streams; i++)
    {
        if(input_context->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO)
        {
            video_stream_index = i;
            input_video_stream = input_context->streams[i];
            break;
        }
    }
    
    if(video_stream_index == -1)
    {
        NSLog(@"Could not find video stream in input context");
        dispatch_async(self.callerQueue, ^{
            if (onComplete) onComplete(NO,0,nil);
        });
        return EXIT_FAILURE;
    }
    // }}}
    
    // {{{ Init output_context and create video stream
    
    AVFormatContext *output_context = NULL;
    AVOutputFormat *output_format = NULL;
    AVStream *output_video_stream = NULL;

    err = init_output_context (&output_context,&output_format,&output_video_stream,input_video_stream,save_path);
    
    if(0 == output_context || err == EXIT_FAILURE)
    {
        NSLog(@"Could not initialize output context");
        dispatch_async(self.callerQueue, ^{
            if (onComplete) onComplete(NO,0,nil);
        });
        return EXIT_FAILURE;
    }
    
    AVPacket packet;
    av_init_packet(&packet);
    
    CFAbsoluteTime start_time = CFAbsoluteTimeGetCurrent();
    
    while(av_read_frame(input_context, &packet) >= 0)
    {
        if(packet.stream_index == video_stream_index)
        {
            packet.stream_index = output_video_stream->index;
            int err2 = av_interleaved_write_frame(output_context, &packet);
//            LOG_ERR(err2, "av_interleaved_write_frame");
        }
        else
        {
            NSLog(@"packet.stream_index != video_stream_index");
        }
        
        av_free_packet(&packet);
        
        int elapsed_time = (int)(CFAbsoluteTimeGetCurrent() - start_time);
        if(elapsed_time > duration)
        {
            av_write_trailer(output_context);
            avio_close(output_context->pb);
            avformat_free_context(output_context);
         
            output_context = NULL;
            output_format = NULL;
            output_video_stream = NULL;

            NSLog(@"recording finished for filename: %@",save_path);
            dispatch_sync(self.callerQueue, ^{
                if (onComplete) onComplete(YES,start_time,save_path);
            });
            
            if (self.shouldStop)
            {
                NSLog(@"aborting, shouldStop == 1");
                break;
            }
            else
            {
                //switch output contexts
                NSLog(@"switch output contexts");

                err = init_output_context (&output_context,&output_format,&output_video_stream,input_video_stream,save_path);
                
                if(0 == output_context)
                {
                    NSLog(@"Could not initialize output context");
                    dispatch_async(self.callerQueue, ^{
                        if (onComplete) onComplete(NO,0,nil);
                    });
                    break;
                }
                
                start_time = CFAbsoluteTimeGetCurrent();
            }
        }
    }
    
    av_read_pause(input_context);
    avformat_close_input(&input_context);
//    av_write_trailer(output_context);
//    avio_close(output_context->pb);
//    avformat_free_context(output_context);
    
    return EXIT_SUCCESS;
}


+ (void) saveMovieToCameraRoll:(NSString*) filepath
{
    static dispatch_once_t onceToken;
    static NSLock* saveLock;
    dispatch_once(&onceToken, ^{
        saveLock = [[NSLock alloc] init];
    });
    
    // save the movie to the camera roll
	ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
	NSLog(@"writing \"%@\" to photos album", filepath);
    
    NSURL* movieURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@",filepath]];
    
    [saveLock lock];
    
	[library writeVideoAtPathToSavedPhotosAlbum:movieURL
								completionBlock:
     ^(NSURL *assetURL, NSError *error)
     {
         [saveLock unlock];
         
         if (error) {
             NSLog(@"assets library failed (%@)", error);
         }
         else
         {
            [[NSFileManager defaultManager] removeItemAtURL:movieURL error:&error];
             if (error)
             {
                 NSLog(@"Couldn't remove temporary movie file \"%@\"", movieURL);
             }
             else
             {
                 NSLog(@"movie saved done");
             }
         }
     }];
}

int open_input_context(AVFormatContext** input_context ,const char * url_address)
{
    *input_context = avformat_alloc_context();
    AVDictionary *options = NULL;
    
    av_dict_set(&options, "rtsp_transport", "tcp", 0);
    
    NSLog(@"open input");
    int err = avformat_open_input(input_context, url_address, NULL, &options);

    if( err < 0)
    {
        char errbuf[400];
        av_strerror(err,errbuf,400);
        NSLog(@"%s failed with error %s","avformat_open_input",errbuf);
        return EXIT_FAILURE;
    }
    err = avformat_find_stream_info(*input_context, NULL);
    if( err < 0)
    {
        char errbuf[400];
        av_strerror(err,errbuf,400);
        NSLog(@"%s failed with error %s","avformat_find_stream_info",errbuf);
        return EXIT_FAILURE;
    }
    
    return EXIT_SUCCESS;
}

+(void) concatenateVideoAtPath:(NSString*) file1 withVideo:(NSString*)file2 toPath:( NSString*) outputPath onDone:(void (^)(void))onComplete
{
    if(NO == [[NSFileManager defaultManager] fileExistsAtPath:file1])
    {
        NSLog(@"file not found at path: %@",file1);
        return;
    }
    
    if(NO == [[NSFileManager defaultManager] fileExistsAtPath:file2])
    {
        NSLog(@"file not found at path: %@",file2);
        return;
    }
    
    //Here where load our movie Assets using AVURLAsset
    AVURLAsset* asset1 = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:file1] options:nil];
    AVURLAsset* asset2 = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:file2] options:nil];
    
    AVMutableComposition* composition = [[AVMutableComposition alloc] init];
    
    //Here we are creating the first AVMutableCompositionTrack. See how we are adding a new track to our AVMutableComposition.
    AVMutableCompositionTrack *track1 = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    //Now we set the length of the firstTrack equal to the length of the firstAsset and add the firstAsset to out newly created track at kCMTimeZero so video plays from the start of the track.
    [track1 insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset1.duration) ofTrack:[[asset1 tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
    
    [track1 insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset2.duration) ofTrack:[[asset2 tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:CMTimeAdd(kCMTimeZero,asset1.duration) error:nil];
    
    AVMutableVideoCompositionInstruction * mainInstruct = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruct.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeAdd(asset1.duration, asset2.duration));
    
    AVMutableVideoCompositionLayerInstruction *layerInstruct1 = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:track1];
    
    mainInstruct.layerInstructions = @[layerInstruct1];
    
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.instructions = @[mainInstruct];
    //    mainInstruct.frameDuration = CMTimeMake(1, 30);
    //    mainInstruct.renderSize = CGSizeMake(640, 480);
    
    if([[NSFileManager defaultManager] fileExistsAtPath:outputPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
    }
    
    NSURL *url = [NSURL fileURLWithPath:outputPath];
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
    exporter.outputURL=url;
    exporter.outputFileType=AVFileTypeQuickTimeMovie;
    
    [exporter exportAsynchronouslyWithCompletionHandler:
     ^{
         if (exporter.status == AVAssetExportSessionStatusCompleted)
         {
             NSLog(@"videos concatenated to %@",outputPath);
         }
         else
         {
             NSLog(@"concatenation failed with error to %@",[exporter.error localizedDescription]);
         }
         if (onComplete) onComplete ();
     }];
}

+(void) cutVideoAtPath:(NSString*)file1 inRange:(CMTimeRange)cutRange toPath:(NSString*) outputPath onDone:(void (^)(void))onComplete
{
    if(NO == [[NSFileManager defaultManager] fileExistsAtPath:file1])
    {
        NSLog(@"file not found at path: %@",file1);
        return;
    }
    
    //Here where load our movie Assets using AVURLAsset
    AVURLAsset* asset1 = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:file1] options:nil];
    
    AVMutableComposition* composition = [[AVMutableComposition alloc] init];
    
    //Here we are creating the first AVMutableCompositionTrack. See how we are adding a new track to our AVMutableComposition.
    AVMutableCompositionTrack *track1 = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    //Now we set the length of the firstTrack equal to the length of the firstAsset and add the firstAsset to out newly created track at kCMTimeZero so video plays from the start of the track.
    [track1 insertTimeRange:cutRange ofTrack:[[asset1 tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
    
    AVMutableVideoCompositionInstruction * mainInstruct = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruct.timeRange = CMTimeRangeMake(kCMTimeZero, cutRange.duration);
    
    AVMutableVideoCompositionLayerInstruction *layerInstruct1 = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:track1];
    
    mainInstruct.layerInstructions = @[layerInstruct1];
    
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.instructions = @[mainInstruct];
    //    mainInstruct.frameDuration = CMTimeMake(1, 30);
    //    mainInstruct.renderSize = CGSizeMake(640, 480);
    
    if([[NSFileManager defaultManager] fileExistsAtPath:outputPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
    }
    
    NSURL *url = [NSURL fileURLWithPath:outputPath];
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
    exporter.outputURL=url;
    exporter.outputFileType=AVFileTypeQuickTimeMovie;
    
    [exporter exportAsynchronouslyWithCompletionHandler:
     ^{
         NSLog(@"video cut finished");
         if (onComplete) onComplete ();
     }];
}

@end
