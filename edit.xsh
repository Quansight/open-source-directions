# this is an umdone script for editing an episode
# this is meant to be run from a rever context

![load https://open-source-directions.nyc3.cdn.digitaloceanspaces.com/podcast/osd$VERSION-raw.mp3] && \
![reduce-noise] && \
![remove-silence --reduce-to $SILENCE_REDUCED_TO] && \
![remove-clips --dbfile clips-osd$VERSION.h5] && \
![save osd$VERSION.ogg osd$VERSION.m4a]

![echo done editing episode]
