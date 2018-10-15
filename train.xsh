# this is an umdone script for training on an episode
# this is meant to be run from a rever context

![load https://open-source-directions.nyc3.cdn.digitaloceanspaces.com/podcast/osd$VERSION-raw.mp3] && \
![reduce-noise] && \
![remove-silence --reduce-to $SILENCE_REDUCED_TO] && \
![label --db labels-osd$VERSION.h5]

![echo done]
