# this is an umdone script for editing an episode
# this is meant to be run from a rever context
import os

if 'UMDONE_CACHE_DIR' not in ${...}:
    $UMDONE_CACHE_DIR = os.path.join('rever', 'umdone')

if 'SILENCE_REDUCED_TO' not in ${...}:
    $SILENCE_REDUCED_TO = 0.2

#![reduce-noise] && \
#![fade-in --prefix https://open-source-directions.nyc3.cdn.digitaloceanspaces.com/podcast/intro-jingle.wav] && \
#![fade-out --postfix https://open-source-directions.nyc3.cdn.digitaloceanspaces.com/podcast/outro-jingle.wav] && \

![load https://open-source-directions.nyc3.digitaloceanspaces.com/podcast/osd$VERSION-raw.mp3] && \
![remove-silence --reduce-to $SILENCE_REDUCED_TO] && \
![remove-clips --dbfile clips-osd$VERSION.h5] && \
![save osd$VERSION.ogg osd$VERSION.m4a]

![echo done editing episode]
