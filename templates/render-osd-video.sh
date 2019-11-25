#! /bin/sh

RENDERER="{{ kdenlive_render }}"
MELT="{{ melt }}"

SOURCE_0="file://{{ mlt_file }}"
TARGET_0="file://{{ webm_file }}"
PARAMETERS_0="-pid:20377 in=0 out=85096 $MELT atsc_1080p_2997 avformat - $SOURCE_0 $TARGET_0 f=webm vcodec=libvpx acodec=libvorbis crf=15 vb=0 quality=good aq=7 max-intra-rate=1000 cpu-used=4 threads=1 real_time=-1"
$RENDERER $PARAMETERS_0
