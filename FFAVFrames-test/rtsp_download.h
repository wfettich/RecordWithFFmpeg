//
//  rtsp_download.h
//  RecordWithFFmpeg
//
//  Created by Walter Fettich on 08.07.13.
//  Copyright (c) 2013 none. All rights reserved.
//

#ifndef RecordWithFFmpeg_rtsp_download_h
#define RecordWithFFmpeg_rtsp_download_h

void init_ffmpeg();
int rtsp_download(const char * url_address, const char * save_path, int duration);

#endif
