#!/bin/sh

LIBNAME="ffmpeg"
#ARCHS="armv7 armv7s i386"
ARCHS="armv7"
TARGET_OS=darwin

DIR=`pwd`
XCODE_SELECT="xcode-select"
XCODE=$(${XCODE_SELECT} --print-path)
SDK_VERSION="6.1"

#DISABLED_COMPONENTS="--disable-everything"

ENABLED_COMPONENTS="--enable-protocol=file --enable-demuxer=mov \
                    --enable-muxer=mpegts --enable-bsf=h264_mp4toannexb"

 CONFIGURE_FLAGS=" 
                    --enable-everything"

# CONFIGURE_FLAGS=" 
#                    --enable-cross-compile \
#                    --enable-network \
#                    --enable-demuxer=mov \
#                    --enable-demuxer=h264 \
#                    --enable-protocol=file \
#                    --enable-avformat \
#                    --enable-avcodec \
#                    --enable-decoder=rawvideo \
#                    --disable-decoder=mjpeg \
#                    --disable-decoder=h263 \
#                    --enable-decoder=mpeg4 \
#                    --enable-decoder=h264 \
#                    --enable-parser=h264 \                    
#                    --enable-demuxer=rtsp \
#                    --enable-pic \
#                    --enable-zlib"

# CONFIGURE_FLAGS="--enable-cross-compile
#                --disable-debug 
#                    --disable-ffmpeg \
#                    --enable-demuxer=mov \
#                    --enable-demuxer=h264 \
#                    --enable-protocol=file \
#                    --enable-avformat \
#                    --enable-avcodec \
#                    --enable-decoder=rawvideo \
#                    --disable-decoder=mjpeg \
#                    --disable-decoder=h263 \
#                    --enable-decoder=mpeg4 \
#                    --enable-decoder=h264 \
#                    --enable-parser=h264 \
#                    --enable-network \
#                    --disable-protocol=tcp\
#                    --enable-demuxer=rtsp\
#                    --enable-pic\
#                    --enable-zlib \
#                 ${ENABLED_COMPONENTS}"

   
    
LIBS="libavcodec libavformat libavutil libswscale libavdevice libavfilter \
      libswresample"

# download ffmpeg if necessary
if [ ! -e ${LIBNAME} ]
then
    echo ""
    echo "* downloading ${LIBNAME}..."
    git clone git://source.ffmpeg.org/ffmpeg.git ${LIBNAME}
else
    echo ""
    echo "* using existing ${LIBNAME}"
fi

mkdir -p "${DIR}/bin"

cd ${LIBNAME}

# build process
for ARCH in ${ARCHS}
do

    make clean

    if [ "${ARCH}" == "i386" ]
    then
        PLATFORM="iPhoneSimulator"
        COMPILER="gcc"
        CONFIG_ARCH="i386"
        CPU="i386"
    else
        PLATFORM="iPhoneOS"
        COMPILER="llvm-gcc"
        CONFIG_ARCH="arm"
        CPU="cortex-a9"
    fi

    XCRUN_SDK=$(echo ${PLATFORM} | tr '[:upper:]' '[:lower:]')
    export CC="$(xcrun -sdk ${XCRUN_SDK} -find ${COMPILER})"
    export LD="$(xcrun -sdk ${XCRUN_SDK} -find ld)"
    export AS="$(xcrun -sdk ${XCRUN_SDK} -find as)"
    export AR="$(xcrun -sdk ${XCRUN_SDK} -find ar)"
    export NM="$(xcrun -sdk ${XCRUN_SDK} -find nm)"
    export RANLIB="$(xcrun -sdk ${XCRUN_SDK} -find ranlib)"

    SDK="${XCODE}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDK_VERSION}.sdk"
    export CFLAGS="-arch ${ARCH}"
    export LDFLAGS="-arch ${ARCH} -isysroot ${SDK}"

    echo ""
    echo "* Building ${LIBNAME} for ${PLATFORM} ${SDK_VERSION} (${ARCH})..."

    mkdir -p "${DIR}/bin/${ARCH}"

    ./configure \
        --cc=${CC} \
        --target-os=${TARGET_OS} \
        --arch=${CONFIG_ARCH} \
        --cpu=${CPU} \
        --as='/usr/local/bin/gas-preprocessor.pl ${CC}' \
        --sysroot=${SDK} \
        --extra-cflags='${CFLAGS}' \
        --extra-ldflags='${LDFLAGS}' \
        ${CONFIGURE_FLAGS} \
        --prefix="${DIR}/bin/${ARCH}"

    make -j3 && make install

done

cd ${DIR}

echo ""
echo "* Creating binaries for ${LIBNAME}..."

mkdir -p ${DIR}/lib

# packing process
for LIB in ${LIBS}
do
lipo -create "${DIR}/bin/armv7/lib/${LIB}.a" \
             "${DIR}/bin/armv7s/lib/${LIB}.a" \
             "${DIR}/bin/i386/lib/${LIB}.a" \
             -output "${DIR}/lib/${LIB}.a"
done

mkdir -p ${DIR}/include

FIRST_ARCH="${ARCHS%% *}"
cp -R "${DIR}/bin/${FIRST_ARCH}/include/" "${DIR}/include/"

echo ""
echo "* Finished; ${LIBNAME} binary created for platforms: ${ARCHS}"
