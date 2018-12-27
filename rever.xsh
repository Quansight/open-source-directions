import os

from rever.activity import activity
from xonsh.tools import print_color

$GITHUB_ORG = 'Quansight'
$PROJECT = $GITHUB_REPO = 'open-source-directions'
$UMDONE_CACHE_DIR = os.path.join($REVER_DIR, 'umdone')
$SILENCE_REDUCED_TO = 0.2

EPISODES = None

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
        episodes.append(episode)
    episodes.sort(key=lambda x: x.number)
    EPISODES = episodes
    return EPISODES


@activity
def feed():
    """Generated RSS feed for podcast"""
    episodes = load_episodes()
    from jinja2 import Environment, FileSystemLoader, select_autoescape
    env = Environment(
        loader=FileSystemLoader('templates'),
        autoescape=select_autoescape(['html', 'xml'])
    )
    template = env.get_template('feed.xml')
    from datetime import datetime
    now = datetime.now()
    print_color('{YELLOW}Rendering RSS feed...{NO_COLOR}')
    s = template.render(
        now=now,
        episodes=episodes,
        )
    with open('feed.xml', 'w') as f:
        f.write(s)
    print_color('{YELLOW}success: feed.xml.{NO_COLOR}')
    ![git add feed.xml]
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
        s3cmd put --config=@(cfgfile) @(fname) s3://open-source-directions/podcast/


$ACTIVITIES = ['edit',
               'upload_to_digital_ocean',
               'feed',
               #'tag', 'push_tag'
              ]
$ACTIVITIES_MARK = ['mark']
