import os

from rever.activity import activity
from xonsh.tools import print_color

$GITHUB_ORG = 'Quansight'
$PROJECT = $GITHUB_REPO = 'open-source-directions'
$UMDONE_CACHE_DIR = os.path.join($REVER_DIR, 'umdone')
$SILENCE_REDUCED_TO = 0.2

EPISODES = None
AUDIO_FORMATS = ['ogg', 'm4a']
AUDIO_MIME_TYPES = {
    'ogg': 'audio/ogg',
    'm4a': 'audio/mp4',
    }

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


@activity
def mark():
    """Marks clip data for an audio file."""
    episodes = load_episodes()
    $[umdone mark.xsh]


@activity
def edit():
    """Edits an audio file."""
    episodes = load_episodes()
    $[umdone edit.xsh]


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


$ACTIVITIES = ['edit',
               'upload_to_digital_ocean',
               'update_episode_data',
               'feed',
               'tag',
               'push_tag',
              ]
$ACTIVITIES_MARK = ['mark']
