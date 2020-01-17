import os
import re
import json
import pickle

from rever.activity import activity
from rever.tools import stream_url_progress
from xonsh.tools import print_color

from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request


$GITHUB_ORG = 'Quansight'
$PROJECT = $GITHUB_REPO = 'open-source-directions'
$UMDONE_CACHE_DIR = os.path.join($REVER_DIR, 'umdone')
$SILENCE_REDUCED_TO = 0.2
$XONSH_INTERACTIVE = False

EPISODES = None
AUDIO_FORMATS = ['ogg', 'm4a']
AUDIO_MIME_TYPES = {
    'ogg': 'audio/ogg',
    'm4a': 'audio/mp4',
    }
INTRO_WAV_URL = "https://open-source-directions.nyc3.cdn.digitaloceanspaces.com/podcast/intro-jingle.wav"
OUTRO_WAV_URL = "https://open-source-directions.nyc3.cdn.digitaloceanspaces.com/podcast/outro-jingle.wav"

__xonsh__.commands_cache.threadable_predictors['umdone'] = lambda *a, **k: False


def load_episodes():
    """Loads episode YAML files."""
    global EPISODES
    if EPISODES is not None:
        return EPISODES
    from ruamel.yaml import YAML
    from argparse import Namespace
    episodes = []
    for fname in `episodes/.*\.ya?ml`:
        if fname == 'episodes/TEMPLATE.yaml':
            continue
        yaml = YAML(typ='safe')
        with open(fname) as f:
            episode = Namespace(**yaml.load(f))
        episode.filename = fname
        episodes.append(episode)
    episodes.sort(key=lambda x: x.number)
    EPISODES = episodes
    return EPISODES


@activity
def update_episode_data():
    """Adds episode URLs and sizes to YAML file."""
    episodes = load_episodes()
    episode = episodes[int($VERSION)]
    audio_base = "osd" + str($VERSION) + "."
    url_base = "https://open-source-directions.nyc3.cdn.digitaloceanspaces.com/podcast/osd" + str($VERSION) + "."
    for format in AUDIO_FORMATS:
        setattr(episode, format + "_url", url_base + format)
        setattr(episode, format + "_size", os.stat(audio_base + format).st_size)
    from ruamel.yaml import YAML
    yaml = YAML()
    yaml.default_flow_style = False
    with open(episode.filename, 'w') as f:
        yaml.dump(episode.__dict__, f)
    if len($(git diff @(episode.filename))) > 0:
        ![git add @(episode.filename)]
        ![git commit -m "episode $VERSION metadata updated"]
        ![git push git@github.com:$GITHUB_ORG/$GITHUB_REPO gh-pages]


@activity
def feed():
    """Generate RSS feeds for podcast"""
    episodes = load_episodes()
    from jinja2 import Environment, FileSystemLoader, select_autoescape
    env = Environment(
        loader=FileSystemLoader('templates'),
        autoescape=select_autoescape(['html', 'xml'])
    )
    template = env.get_template('feed.xml')
    from datetime import datetime
    now = datetime.now()
    feed_files = []
    for format in AUDIO_FORMATS:
        print_color('{YELLOW}Rendering ' + format + ' RSS feed...{NO_COLOR}')
        s = template.render(
            now=now,
            episodes=episodes,
            getattr=getattr,
            audio_format=format,
            audio_mime_type=AUDIO_MIME_TYPES[format],
            )
        feed_file = format + '-feed.xml'
        with open(feed_file, 'w') as f:
            f.write(s)
        feed_files.append(feed_file)
        print_color('{YELLOW}success: ' + feed_file + '.{NO_COLOR}')
    ![git add @(feed_files)]
    ![git commit -m "episode $VERSION at @(now.isoformat())"]
    ![git push git@github.com:$GITHUB_ORG/$GITHUB_REPO gh-pages]
    print_color('{YELLOW}Uploading m4a-feed.xml to Digital Ocean for iTunes.{NO_COLOR}')
    cfgfile = os.path.join($REVER_CONFIG_DIR, 'osd.s3cfg')
    s3cmd put --config=@(cfgfile) --acl-public m4a-feed.xml s3://open-source-directions/podcast/


@activity
def mark():
    """Marks clip data for an audio file."""
    __xonsh__.commands_cache.threadable_predictors['umdone'] = lambda *a, **k: False
    episodes = load_episodes()
    $[umdone mark.xsh]


@activity
def edit():
    """Edits an audio file."""
    __xonsh__.commands_cache.threadable_predictors['umdone'] = lambda *a, **k: False
    episodes = load_episodes()
    $[umdone edit.xsh]


@activity
def transcribe_raw():
    """Transcribes a raw audio file."""
    __xonsh__.commands_cache.threadable_predictors['umdone'] = lambda *a, **k: False
    episodes = load_episodes()
    $[umdone transcribe-raw.xsh]


@activity
def upload_to_digital_ocean():
    """Uploads finished audio files to digital ocean"""
    cfgfile = os.path.join($REVER_CONFIG_DIR, 'osd.s3cfg')
    if not os.path.exists(cfgfile):
        msg = ("Digital ocean s3cmd config file does not exist. Please run: \n\n"
               "  $ s3cmd --configure --ssl "
               "--host=nyc3.digitaloceanspaces.com "
               '"--host-bucket=%(bucket)s.nyc3.digitaloceanspaces.com" '
               "--config=" + cfgfile + "\n\n"
               "and fill in with the secret key provided in \n"
               "https://docs.google.com/document/d/1TQLlvPhl6SgLtWxpxoVSzzoeOi7zjijD6pjPqS0k944\n"
               "and select the defaults provided.\n\n"
               "For more information, please see: https://www.digitalocean.com/docs/spaces/resources/s3cmd/\n"
               "\n")
        raise RuntimeError(msg)
    files = g`osd$VERSION.*`
    for fname in files:
        print_color('{YELLOW}Uploading ' + fname + '{NO_COLOR}')
        s3cmd put --config=@(cfgfile) --acl-public @(fname) s3://open-source-directions/podcast/


def download_google_slide_as_png(service, presentation_id, slide, filename):
    """Downloads a google slide as large PNG file."""
    j = service.presentations().pages().getThumbnail(presentationId=presentation_id, pageObjectId=slide['objectId'],
        thumbnailProperties_mimeType="PNG", thumbnailProperties_thumbnailSize="LARGE").execute()
    $[curl -L @(j['contentUrl']) > @(filename)]


def make_google_slides_service():
    """Google Slides interface."""
    scopes = ['https://www.googleapis.com/auth/presentations.readonly']
    creds = None
    token_file = os.path.join($REVER_DIR, 'slides-token.pkl')
    if os.path.exists(token_file):
        with open(token_file, 'rb') as f:
            creds = pickle.load(f)
    # If there are no (valid) credentials available, let the user log in.
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        elif not os.path.isfile('google-creds.json'):
            raise ValueError(
                "Could not find Google credetials. Please copy the contents of "
                "https://docs.google.com/document/d/10iyE_AOKEfz1F10IGHF5NC6Cw0Ob4ccF_IyXNLcWHj4"
                " into the file 'google-creds.json' in this directory."
            )
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                'google-creds.json', scopes)
            creds = flow.run_local_server(port=0)
        # Save the credentials for the next run
        with open(token_file, 'wb') as f:
            pickle.dump(creds, f)

    service = build('slides', 'v1', credentials=creds)
    return service


SLIDES_URL_RE = re.compile("https://docs.google.com/presentation/d/([^/]+)")


@activity
def download_slides():
    """Downloads intro/outro slides from google drive as PNG files."""
    # first get the presentation ID from the metadata
    episodes = load_episodes()
    episode = episodes[int($VERSION)]
    # next get the slide ids
    m = SLIDES_URL_RE.match(episode.slides)
    if m is None:
        raise ValueError(str(episode) + " has invalid 'slides' entry.")
    presentation_id = m.group(1)
    # Call the Slides API
    service = make_google_slides_service()
    presentation = service.presentations().get(presentationId=presentation_id).execute()
    slides = presentation.get('slides')
    # download the slides
    for name, slide in zip(["intro", "outro"], slides):
        fname = f"{$REVER_DIR}/{name}-{episode.number}.png"
        download_google_slide_as_png(service, presentation_id, slide, fname)


@activity
def download_raw_video():
    """Downloads the video (from livestorm)"""
    episodes = load_episodes()
    episode = episodes[int($VERSION)]
    fname = os.path.join($REVER_DIR, f'osd{$VERSION}-raw.mp4')
    with open(fname, 'wb') as f:
        for b in stream_url_progress(episode.raw_video):
            f.write(b)


@activity
def raw_mp3():
    """Converts the video file to a raw MP3 locally."""
    episodes = load_episodes()
    episode = episodes[int($VERSION)]
    mp3 = os.path.join($REVER_DIR, f'osd{$VERSION}-raw.mp3')
    mp4 = os.path.join($REVER_DIR, f'osd{$VERSION}-raw.mp4')
    ![ffmpeg -y -i @(mp4) @(mp3)]


def fps(filename):
    """Gets the frames-per-second of a video file"""
    s = $(ffprobe -print_format json -select_streams v -show_streams @(filename))
    j = json.loads(s)
    frames, _, seconds = j["streams"][0]["avg_frame_rate"].partition("/")
    return int(int(frames) / int(seconds))


@activity
def render_video():
    """Renders MP4 video"""
    episodes = load_episodes()
    episode = episodes[int($VERSION)]
    #from jinja2 import Environment, FileSystemLoader, select_autoescape

    # make intro & outro movies
    ![ffmpeg -y -i $REVER_DIR/intro-$VERSION.png -i $REVER_DIR/intro-jingle.wav $REVER_DIR/intro-$VERSION.mp4]
    ![ffmpeg -y -i $REVER_DIR/outro-$VERSION.png -i $REVER_DIR/outro-jingle.wav $REVER_DIR/outro-$VERSION.mp4]

    # move movies into one another
    intro_fps = fps(f"{$REVER_DIR}/intro-{$VERSION}.mp4")
    outro_fps = fps(f"{$REVER_DIR}/outro-{$VERSION}.mp4")
    raw_fps = fps(f"{$REVER_DIR}/osd{$VERSION}-raw.mp4")
    ![melt $REVER_DIR/intro-$VERSION.mp4 out=@(2*intro_fps) \
           $REVER_DIR/outro-$VERSION.mp4 in=@(*int(raw_fps)) -mix @(raw_fps) -mixer luma \
           $REVER_DIR/outro-$VERSION.mp4 out=@(4*outro_fps) -mix @(outro_fps) -mixer luma \
           -consumer avformat:$REVER_DIR/osd$VERSION.mp4 \
    ]

    # set up jinja
    #env = Environment(
    #    loader=FileSystemLoader('templates'),
    #    autoescape=select_autoescape(['html', 'xml'])
    #)
    #sh_file = os.path.join($REVER_DIR, f'osd{$VERSION}-video.sh')
    #mlt_file = sh_file + ".mlt"
    #intro_wav = os.path.join($REVER_DIR, 'intro-jingle.wav')
    #outro_wav = os.path.join($REVER_DIR, 'outro-jingle.wav')
    #ctx = dict(
    #    cwd=$PWD,
    #    episode=episode,
    #    kdenlive_render=$(which kdenlive_render),
    #    melt=$(which melt),
    #    mlt_file=mlt_file,
    #    raw_mp4=os.path.join($REVER_DIR, f'osd{$VERSION}-raw.mp4'),
    #    webm_file=os.path.join($REVER_DIR, f'osd{$VERSION}.webm'),
    #    intro_slide=os.path.join($REVER_DIR, f'intro-{$VERSION}.png'),
    #    outro_slide=os.path.join($REVER_DIR, f'outro-{$VERSION}.png'),
    #    intro_wav=intro_wav,
    #    outro_wav=outro_wav,
    #)
    # download intro/outro sounds
    #if not os.path.isfile(intro_wav):
    #    with open(intro_wav, 'wb') as f:
    #        for b in stream_url_progress(INTRO_WAV_URL):
    #            f.write(b)
    #if not os.path.isfile(outro_wav):
    #    with open(outro_wav, 'wb') as f:
    #        for b in stream_url_progress(OUTRO_WAV_URL):
    #            f.write(b)

    # create render script
    #sh_template = env.get_template('render-osd-video.sh')
    #sh = sh_template.render(**ctx)
    #with open(sh_file, 'w') as f:
    #    f.write(sh)

    # fill in render template
    #mlt_template = env.get_template('render-osd-video.sh.mlt')
    #mlt = mlt_template.render(**ctx)
    #with open(mlt_file, 'w') as f:
    #    f.write(mlt)



$ACTIVITIES = [
    'download_slides',
    'download_raw_video',
    'raw_mp3',
    'transcribe_raw',
    'render_video',
    'edit',
    'upload_to_digital_ocean',
    'update_episode_data',
    'feed',
    'tag',
    'push_tag',
]
$ACTIVITIES_MARK = ['mark']
