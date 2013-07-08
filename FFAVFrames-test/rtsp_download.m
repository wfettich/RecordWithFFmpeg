
#include "libavutil/avutil.h"
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#import <AssetsLibrary/AssetsLibrary.h>

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


NSObject* mutex;

AVFormatContext* open_input_context(const char * url_address);
int init_stream_copy(AVFormatContext *oc, AVCodecContext *codec, AVStream *ost, AVCodecContext *icodec, AVStream *ist);
void saveMovieToCameraRoll();

void init_ffmpeg()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mutex = [[NSObject alloc] init];
    });
    
    av_register_all();
    avformat_network_init();
}

int rtsp_download(const char * url_address, const char * save_path, int duration)
{
//    NSLog(@"ffmpeg version %s",LIBAVFORMAT_IDENT);
//    const char* build_conf = avformat_configuration();
//    NSLog(@"ffmpeg build conf %s",build_conf);

    AVFormatContext *input_context;
    @synchronized(mutex)
    {
//        NSLog(@"lock acquired for path: %s",save_path);
        input_context = open_input_context(url_address);
        if ((int)input_context == EXIT_FAILURE)
        {
            NSLog(@"input_context is invalid");
            return EXIT_FAILURE;
        }
//        NSLog(@"lock released for path: %s",save_path);
    }
    AVFormatContext *output_context = NULL;
    AVOutputFormat *output_format;
    AVStream *output_video_stream = NULL, *input_video_stream = NULL;
    int video_stream_index = -1;

    if(!input_context)
    {
        NSLog(@"input_context is nil");
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
        return EXIT_FAILURE;
    }
    // }}}

    // {{{ Init output_context and create video stream
    
    avformat_alloc_output_context2(&output_context, NULL, NULL, save_path);
    if(!output_context)
    {
        NSLog(@"Could not deduce output format from file extension");
        return EXIT_FAILURE;
    }
    output_format = output_context->oformat;

    if(output_format->video_codec != AV_CODEC_ID_NONE)
    {
        output_video_stream = avformat_new_stream(output_context, input_video_stream->codec->codec);
        if(output_format->flags & AVFMT_GLOBALHEADER)
            output_video_stream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
    }

    int err = init_stream_copy(output_context, output_video_stream->codec, output_video_stream,
	    input_video_stream->codec, input_video_stream);
    
    LOG_ERR_AND_EXIT(err, "init_stream_copy");

    err = avio_open(&output_context->pb, save_path, AVIO_FLAG_WRITE);
    LOG_ERR_AND_EXIT(err, "avio_open");
    
    err = avformat_write_header(output_context, NULL);
    LOG_ERR_AND_EXIT(err, "avformat_write_header");


    AVPacket packet;
    av_init_packet(&packet);

    CFAbsoluteTime start_time = CFAbsoluteTimeGetCurrent();
    
    while(av_read_frame(input_context, &packet) >= 0)
    {
        if(packet.stream_index == video_stream_index)
        {
            packet.stream_index = output_video_stream->index;
            int err = av_interleaved_write_frame(output_context, &packet);
            LOG_ERR(err, "av_interleaved_write_frame");
        }

        av_free_packet(&packet);

        int elapsed_time = (int)(CFAbsoluteTimeGetCurrent() - start_time);
        if(elapsed_time > duration)
            break;
    }

    av_read_pause(input_context);
    av_write_trailer(output_context);
    avio_close(output_context->pb);
    avformat_close_input(&input_context);
    avformat_free_context(output_context);

    dispatch_async(dispatch_get_main_queue(), ^{
        saveMovieToCameraRoll(save_path);
    });
    
    NSLog(@"recording finished for filename: %s",save_path);
    return 1;
}


void saveMovieToCameraRoll(const char* filepath)
{
    // save the movie to the camera roll
	ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
	NSLog(@"writing \"%s\" to photos album", filepath);
    
    NSURL* movieURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%s",filepath]];
    
	[library writeVideoAtPathToSavedPhotosAlbum:movieURL
								completionBlock:
     ^(NSURL *assetURL, NSError *error)
     {
         if (error) {
             NSLog(@"assets library failed (%@)", error);
         }
         else {
             [[NSFileManager defaultManager] removeItemAtURL:movieURL error:&error];
             if (error)
                 NSLog(@"Couldn't remove temporary movie file \"%@\"", movieURL);
         }
     }];
}

AVFormatContext* open_input_context(const char * url_address)
{
    AVFormatContext *input_context = avformat_alloc_context();
    AVDictionary *options = NULL;

    av_dict_set(&options, "rtsp_transport", "tcp", 0);

    int err = avformat_open_input(&input_context, url_address, NULL, &options);
    LOG_ERR_AND_EXIT(err, "avformat_open_input");
    
    err = avformat_find_stream_info(input_context, NULL);
    LOG_ERR_AND_EXIT(err, "avformat_find_stream_info");
    
    return input_context;
}
