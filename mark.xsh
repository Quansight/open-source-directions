# this is an umdone script for training on an episode
# this is meant to be run from a rever context
import os

if 'UMDONE_CACHE_DIR' not in ${...}:
    $UMDONE_CACHE_DIR = os.path.join('rever', 'umdone')

if 'SILENCE_REDUCED_TO' not in ${...}:
    $SILENCE_REDUCED_TO = 0.2

![load https://open-source-directions.nyc3.cdn.digitaloceanspaces.com/podcast/osd$VERSION-raw.mp3] && \
![reduce-noise] && \
![remove-silence --reduce-to $SILENCE_REDUCED_TO] && \
![mark-clips --db clips-osd$VERSION.h5]

![echo done]
