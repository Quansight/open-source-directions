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


$ACTIVITIES = ['edit', 'feed',
               #'tag', 'push_tag'
              ]
$ACTIVITIES_TRAIN = ['mark']
