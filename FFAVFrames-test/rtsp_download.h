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
int rtsp_download(const char * url_address, const char * save_path, int duration, void (^onComplete)(void));
void concatenateVideos(NSString* file1,NSString* file2, NSString* outputPath,void (^onComplete)(void));
void saveMovieToCameraRoll(const char* filepath);
void cutVideo(NSString* file1,CMTimeRange cutRange, NSString* outputPath,void (^onComplete)(void));
#endif
