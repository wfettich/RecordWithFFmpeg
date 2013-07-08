#include "libavutil/avutil.h"
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"

int init_stream_copy(AVFormatContext *oc, AVCodecContext *codec, AVStream *ost, AVCodecContext *icodec, AVStream *ist)
{
    AVRational sar;
    uint64_t extra_size;
    int copy_tb = -1;

    extra_size = (uint64_t)icodec->extradata_size + FF_INPUT_BUFFER_PADDING_SIZE;

    if (extra_size > INT_MAX) {
	return AVERROR(EINVAL);
    }

    /* if stream_copy is selected, no need to decode or encode */
    codec->codec_id   = icodec->codec_id;
    codec->codec_type = icodec->codec_type;

    if (!codec->codec_tag) {
//	unsigned int codec_tag;
	if (!oc->oformat->codec_tag ||
		av_codec_get_id (oc->oformat->codec_tag, icodec->codec_tag) == codec->codec_id ||
		0 != av_codec_get_tag(oc->oformat->codec_tag, icodec->codec_id))
	    codec->codec_tag = icodec->codec_tag;
    }

    codec->bit_rate       = icodec->bit_rate;
    codec->rc_max_rate    = icodec->rc_max_rate;
    codec->rc_buffer_size = icodec->rc_buffer_size;
    codec->field_order    = icodec->field_order;
    
    //ERROR HERE!!!!
    codec->extradata      = (uint8_t*) av_mallocz(extra_size);    
    
    if (!codec->extradata) {
	return AVERROR(ENOMEM);
    }
    memcpy(codec->extradata, icodec->extradata, icodec->extradata_size);
    codec->extradata_size= icodec->extradata_size;
    codec->bits_per_coded_sample  = icodec->bits_per_coded_sample;

    codec->time_base = ist->time_base;
    /*
     * Avi is a special case here because it supports variable fps but
     * having the fps and timebase differe significantly adds quite some
     * overhead
     */
    if(!strcmp(oc->oformat->name, "avi")) {
	if (( copy_tb<0 && av_q2d(ist->r_frame_rate) >= av_q2d(ist->avg_frame_rate)
		&& 0.5/av_q2d(ist->r_frame_rate) > av_q2d(ist->time_base)
		&& 0.5/av_q2d(ist->r_frame_rate) > av_q2d(icodec->time_base)
		&& av_q2d(ist->time_base) < 1.0/500 && av_q2d(icodec->time_base) < 1.0/500)
		|| copy_tb==2){
	    codec->time_base.num = ist->r_frame_rate.den;
	    codec->time_base.den = 2*ist->r_frame_rate.num;
	    codec->ticks_per_frame = 2;
	} else if (   (copy_tb<0 && av_q2d(icodec->time_base)*icodec->ticks_per_frame > 2*av_q2d(ist->time_base)
		&& av_q2d(ist->time_base) < 1.0/500)
		|| copy_tb==0){
	    codec->time_base = icodec->time_base;
	    codec->time_base.num *= icodec->ticks_per_frame;
	    codec->time_base.den *= 2;
	    codec->ticks_per_frame = 2;
	}
    } else if(!(oc->oformat->flags & AVFMT_VARIABLE_FPS)
	    && strcmp(oc->oformat->name, "mov") && strcmp(oc->oformat->name, "mp4") && strcmp(oc->oformat->name, "3gp")
	    && strcmp(oc->oformat->name, "3g2") && strcmp(oc->oformat->name, "psp") && strcmp(oc->oformat->name, "ipod")
	    && strcmp(oc->oformat->name, "f4v")
	    ) {
	if(   (copy_tb<0 && icodec->time_base.den
		&& av_q2d(icodec->time_base)*icodec->ticks_per_frame > av_q2d(ist->time_base)
		&& av_q2d(ist->time_base) < 1.0/500)
		|| copy_tb==0){
	    codec->time_base = icodec->time_base;
	    codec->time_base.num *= icodec->ticks_per_frame;
	}
    }

    av_reduce(&codec->time_base.num, &codec->time_base.den,
	    codec->time_base.num, codec->time_base.den, INT_MAX);

    // Video only : 
    {
	codec->pix_fmt            = icodec->pix_fmt;
	codec->width              = icodec->width;
	codec->height             = icodec->height;
	codec->has_b_frames       = icodec->has_b_frames;
	if (ist->sample_aspect_ratio.num)
	    sar = ist->sample_aspect_ratio;
	else
	    sar = icodec->sample_aspect_ratio;
	ost->sample_aspect_ratio = codec->sample_aspect_ratio = sar;
	ost->avg_frame_rate = ist->avg_frame_rate;
    }

    return 0;
}
