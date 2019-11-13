# this is an umdone script for finding the location where a
# webinar starts in an MP3
import os

if 'UMDONE_CACHE_DIR' not in ${...}:
    $UMDONE_CACHE_DIR = os.path.join('rever', 'umdone')

if 'SILENCE_REDUCED_TO' not in ${...}:
    $SILENCE_REDUCED_TO = 0.2

transcript_file = os.path.join('rever', 'umdone', 'aws', 'osd' + $VERSION + '-raw.json')

![aws-transcribe umdone rever/osd$VERSION-raw.mp3 --transcript-file @(transcript_file)]

![echo done transcribing @(transcript_file)]
