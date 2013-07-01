/**
this is the wrapper of the native functions 
**/
/*android specific headers*/
//#include <jni.h>
//#include <android/log.h>
//#include <android/bitmap.h>
/*standard library*/
#include <time.h>
#include <math.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <unistd.h>
#include <assert.h>
/*ffmpeg headers*/
#include "libavutil/avstring.h"
#include "libavutil/pixdesc.h"
#include "libavutil/imgutils.h"
#include "libavutil/samplefmt.h"

#include "libavformat/avformat.h"
#include "libswscale/swscale.h"

#include "libavcodec/avcodec.h"
//#include <libavcodec/opt.h>
#include "libavcodec/avfft.h"
#include "libavformat/avio.h" 
#include <mach/mach_time.h>
/*for android logs*/

#define LOG_LEVEL 10
//#define LOGI(level, ...) if (level <= LOG_LEVEL) {__android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__);}
//#define LOGE(level, ...) if (level <= LOG_LEVEL) {__android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__);}

/**/
char *gFileName;	  //the file name of the video

AVFormatContext *gFormatCtx;
int gVideoStreamIndex;    //video stream index

AVCodecContext *gVideoCodecCtx;

  AVCodecContext  *pCodecCtx;
  AVCodec         *pCodec;


static double now_ms(void)
{
    return mach_absolute_time() * 1000;

//    struct timespec res;
//    return 1000.0 * res.tv_sec + (double) res.tv_nsec / 1e6;
}

#if DONT_COMPILE == 1
- (kxMovieError) openVideoStream: (NSInteger) videoStream
{
    // get a pointer to the codec context for the video stream
    AVCodecContext *codecCtx = _formatCtx->streams[videoStream]->codec;
    
    // find the decoder for the video stream
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if (!codec)
        return kxMovieErrorCodecNotFound;
    
    // inform the codec that we can handle truncated bitstreams -- i.e.,
    // bitstreams where frame boundaries can fall in the middle of packets
    //if(codec->capabilities & CODEC_CAP_TRUNCATED)
    //    _codecCtx->flags |= CODEC_FLAG_TRUNCATED;
    
    // open codec
    if (avcodec_open2(codecCtx, codec, NULL) < 0)
        return kxMovieErrorOpenCodec;
    
    _videoFrame = avcodec_alloc_frame();
    
    if (!_videoFrame) {
        avcodec_close(codecCtx);
        return kxMovieErrorAllocateFrame;
    }
    
    _videoStream = videoStream;
    _videoCodecCtx = codecCtx;
    
    // determine fps
    
    AVStream *st = _formatCtx->streams[_videoStream];
    avStreamFPSTimeBase(st, 0.04, &_fps, &_videoTimeBase);
    
    NSLog(@"video codec size: %d:%d fps: %.3f tb: %f",
          self.frameWidth,
          self.frameHeight,
          _fps,
          _videoTimeBase);
    
    NSLog(@"video start time %f", st->start_time * _videoTimeBase);
    NSLog(@"video disposition %d", st->disposition);
    
    return kxMovieErrorNone;
}
#endif

int downloadSegment(
                     const char* url_adress,
                     const char* save_path,
                     int duration
                     )
{
//double jni_start=now_ms();
//LOGE(10, "jni start: %f",jni_start);
//jclass cls = (*pEnv)->GetObjectClass(pEnv, pObj);
  // jstring jstr = (*pEnv)->NewStringUTF(pEnv, "1");
//jmethodID mid = (*pEnv)->GetMethodID(pEnv, cls, "callFromC", "(Ljava/lang/String;)Ljava/lang/String;");
 //jobject result = (*pEnv)->CallObjectMethod(pEnv, pObj, mid, jstr);


//const char* str2 = "true";
    int video_stream_index;

    av_register_all();
    avcodec_register_all();
    avformat_network_init();
    const char* build_conf = avformat_configuration();
    NSLog(@"ffmpeg build conf %s",build_conf);
    
    AVFormatContext* context = avformat_alloc_context();

    //open rtsp
    AVDictionary *options=NULL;
    av_dict_set(&options, "rtsp_transport","udp",0);
    //av_dict_set(&options,"r","100",0);
    //test video, always working: rtsp://184.72.239.149/vod/mp4://BigBuckBunny_175k.mov

    int error = avformat_open_input(&context, url_adress,NULL,&options);
   if( error != 0)
   {
       char errbuf[400];
       av_strerror(error,errbuf,400);
       NSLog(@"avformat_open_input failed with error %s",errbuf);
       return EXIT_FAILURE;
    }

    NSLog(@"XX 1");
    if(avformat_find_stream_info(context,NULL) < 0)
    {
        char errbuf[400];
        av_strerror(error,errbuf,400);
        NSLog(@"avformat_find_stream_info failed with error %s",errbuf);

        return EXIT_FAILURE;
    }
 //search video stream
    for(int  i =0;i<context->nb_streams;i++)
    {
        if(context->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO)
        {
            video_stream_index = i;
            NSLog(@"XX 2");
        }
    }
    NSLog(@"XX 3");
    AVPacket packet;
    av_init_packet(&packet);

    //open output file
    AVOutputFormat* fmt = av_guess_format("mp4",NULL,NULL);

    AVFormatContext* oc = avformat_alloc_context();
//    AVFormatContext* oc = context;
    oc->oformat = fmt;
    oc->duration=100;
    AVDictionary *options2=NULL;
    
    //av_dict_set(&options2,"r","1",0);
    avio_open2(&oc->pb, save_path, AVIO_FLAG_WRITE,NULL,NULL);
    
    NSLog(@"XX 4");
    AVStream* stream=NULL;
    int cnt = 0;
    //start reading packets from stream and write them to file

   // av_read_play(context);//play RTSP
    double delta=0;
    double start_ms=-1;
    
    NSLog(@"XX 5");
    while(av_read_frame(context,&packet)>=0 &&delta<duration)
    {
        NSLog(@"cnt:: %d",cnt);
        NSLog(@"delta= %f", delta);
        if(start_ms==-1)
        {
            start_ms=now_ms();
            NSLog(@"bucla start= %f", start_ms);
        }
        
        double curent_ms=now_ms();
        delta = curent_ms - start_ms;

//        const char* str = (*pEnv)->GetStringUTFChars(pEnv,(jstring) result, NULL);
//        NSLog(@"%s\n", str);
//        NSLog(@"cmp: %d",strcmp(str,str2));
        NSLog(@"XX 6");

        if(packet.stream_index == video_stream_index)
        {//packet is video
            NSLog(@"XX 7");
            if(stream == NULL)
            {//create stream in file
                NSLog(@"XX 8");
                stream = avformat_new_stream(oc,context->streams[video_stream_index]->codec->codec);

                avcodec_copy_context(stream->codec,context->streams[video_stream_index]->codec);

                stream->sample_aspect_ratio = context->streams[video_stream_index]->codec->sample_aspect_ratio;
                stream->codec->time_base.den=93000;  //invers prop cu lungimea filmului
                avformat_write_header(oc,NULL);

            }
            packet.stream_index = stream->id;
            int a=av_write_frame(oc,&packet);
NSLog(@"a: %d",a);
            cnt++;
        }

       av_free_packet(&packet);
    }
    
    NSLog(@"XX 9");
    av_read_pause(context);
    av_write_trailer(oc);
    avio_close(oc->pb);
    avformat_free_context(oc);

    return (EXIT_SUCCESS);
}	




