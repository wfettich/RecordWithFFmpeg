
#include "libavutil/avutil.h"
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"

AVFormatContext* open_input_context(const char * url_address);
int init_stream_copy(AVFormatContext *oc, AVCodecContext *codec, AVStream *ost, AVCodecContext *icodec, AVStream *ist);

int rtsp_download(const char * url_address, const char * save_path, int duration)
{
    av_register_all();
    avformat_network_init();

    AVFormatContext *input_context = open_input_context(url_address);
    AVFormatContext *output_context = NULL;
    AVOutputFormat *output_format;
    AVStream *output_video_stream = NULL, *input_video_stream = NULL;
    int video_stream_index = -1;

    // {{{ Verify input_context and get video_stream
    if(!input_context)
	return EXIT_FAILURE;

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
    
    output_context = avformat_alloc_context();
    AVOutputFormat* fmt = av_guess_format("mp4",NULL,NULL);
    output_context->oformat = fmt;
//    avformat_alloc_output_context2(&output_context, NULL, NULL, save_path);
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

    init_stream_copy(output_context, output_video_stream->codec, output_video_stream,
	    input_video_stream->codec, input_video_stream);

//    avio_open2(&outContext->pb, save_path, AVIO_FLAG_WRITE,NULL,NULL);
//    if(avio_open(&output_context->pb, save_path, AVIO_FLAG_WRITE) < 0)
    if(avio_open2(&output_context->pb, save_path, AVIO_FLAG_WRITE,NULL,NULL) < 0)
    {
        NSLog(@"Could not open output file");
        return EXIT_FAILURE;
    }
    avformat_write_header(output_context, NULL);
    // }}} 

    AVPacket packet;
    av_init_packet(&packet);

    CFAbsoluteTime start_time = CFAbsoluteTimeGetCurrent();
    
    while(av_read_frame(input_context, &packet) >= 0)
    {
        if(packet.stream_index == video_stream_index)
        {
            packet.stream_index = output_video_stream->index;
            av_interleaved_write_frame(output_context, &packet);
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

    return 1;
}

AVFormatContext* open_input_context(const char * url_address)
{
    AVFormatContext *input_context = avformat_alloc_context();
    AVDictionary *options = NULL;

    av_dict_set(&options, "rtsp_transport", "udp", 0);

    if(avformat_open_input(&input_context, url_address, NULL, &options) < 0)
    {
        NSLog(@"Failed to open input context");
        return NULL;
    }

    if(avformat_find_stream_info(input_context, NULL) < 0)
    {
        NSLog(@"Failed to find stream info");
        return NULL;
    }

    return input_context;
}
