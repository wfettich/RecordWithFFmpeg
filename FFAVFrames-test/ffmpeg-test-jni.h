//
//  ffmpeg-test-jni.h
//  RecordWithFFmpeg
//
//  Created by Walter Fettich on 21.06.13.
//  Copyright (c) 2013 none. All rights reserved.
//

#ifndef RecordWithFFmpeg_ffmpeg_test_jni_h
#define RecordWithFFmpeg_ffmpeg_test_jni_h

int downloadSegment(
                    const char* url_adress,
                    const char* save_path,
                    int duration
                    );


#endif
