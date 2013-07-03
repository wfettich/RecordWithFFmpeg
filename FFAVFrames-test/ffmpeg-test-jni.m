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
#include "libavutil/opt.h"
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

#define LOG_ERR(err,func) \
if( err < 0) \
{\
    char errbuf[400]; \
    av_strerror(err,errbuf,400); \
    NSLog(@"%s failed with error %s",func,errbuf); \
    return EXIT_FAILURE; \
}

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
    NSLog(@"ffmpeg version %s",LIBAVFORMAT_IDENT);
    const char* build_conf = avformat_configuration();
    NSLog(@"ffmpeg build conf %s",build_conf);
    
    AVFormatContext* inContext = avformat_alloc_context();

    //open rtsp
    AVDictionary *options=NULL;
    av_dict_set(&options, "rtsp_transport","udp",0);
    //av_dict_set(&options,"r","100",0);
    //test video, always working: rtsp://184.72.239.149/vod/mp4://BigBuckBunny_175k.mov

    int err = avformat_open_input(&inContext, url_adress,NULL,&options);
    LOG_ERR(err, "avformat_open_input")
    
    NSLog(@"XX 1");
    err = avformat_find_stream_info(inContext,NULL);
    LOG_ERR(err, "avformat_find_stream_info")
    
    //search video stream
    for(int  i =0;i<inContext->nb_streams;i++)
    {
        if(inContext->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO)
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

    AVFormatContext* outContext = avformat_alloc_context();
//    AVFormatContext* oc = context;
    outContext->oformat = fmt;
//    oc->duration=100;
    
    AVDictionary *options2=NULL;
    //av_dict_set(&options2,"r","1",0);
    avio_open2(&outContext->pb, save_path, AVIO_FLAG_WRITE,NULL,NULL);
    
    NSLog(@"XX 4");
    AVStream* stream=NULL;
    int cnt = 0;
    //start reading packets from stream and write them to file

   // av_read_play(context);//play RTSP
    double delta=0;
    double start_ms=-1;
    
    NSLog(@"XX 5");
    while(av_read_frame(inContext,&packet)>=0 &&delta<duration)
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
                stream = avformat_new_stream(outContext,inContext->streams[video_stream_index]->codec->codec);

                avcodec_copy_context(stream->codec,inContext->streams[video_stream_index]->codec);

                stream->sample_aspect_ratio = inContext->streams[video_stream_index]->codec->sample_aspect_ratio;
                
                stream->codec->time_base.den=93000;  //invers prop cu lungimea filmului
                err = avformat_write_header(outContext,NULL);
                LOG_ERR(err, "avformat_write_header")
            }
            packet.stream_index = stream->id;
            int a=av_write_frame(outContext,&packet);
            LOG_ERR(a,"av_write_frame")
            cnt++;
        }

       av_free_packet(&packet);
    }
    
    NSLog(@"XX 9");
    av_read_pause(inContext);
    av_write_trailer(outContext);
    avio_close(outContext->pb);
    avformat_free_context(outContext);

    return (EXIT_SUCCESS);
}	




