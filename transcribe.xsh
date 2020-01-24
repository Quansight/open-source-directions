# this is an umdone script for finding the location where a
# webinar starts in an MP3
import os

if 'UMDONE_CACHE_DIR' not in ${...}:
    $UMDONE_CACHE_DIR = os.path.join('rever', 'umdone')

transcript_file = os.path.join($REVER_DIR, 'umdone', 'aws', 'osd' + $VERSION + '-raw.json')

![aws-transcribe umdone $REVER_DIR/osd$VERSION-raw-audio.mp3 --transcript-file @(transcript_file)]

![echo done transcribing @(transcript_file)]
