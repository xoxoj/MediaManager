#!/bin/sh
cp ./build/Debug-iphoneos/libMediaManager.a ./deploy/lib/

cp ./MediaManager/MediaManager.h ./deploy/include/
cp ./corelibs/video/KNVideoManager.h ./deploy/include/
cp ./corelibs/Global.h ./deploy/include/

