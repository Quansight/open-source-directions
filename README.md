# Open Source Directions
Podcast feed for Open Source Directions

This is based on [jekyll-now](https://github.com/barryclark/jekyll-now).

## Directions for Installing Dependencies

First, we need to create an environment with most of our dependencies.
In the repo directory, run:

```sh
$ conda env create
```

This will create an `osd` environment. We will then need to activate this
anytime we need to do any work!

```sh
$ conda activate osd
```

Lastly, to install, we'll need to have `umdone` project. This is currently
an internal Quansight project and so there is no conda package available.
We will need to grab the repo and install it.

```sh
(osd) $ git clone git@github.com:scopatz/umdone.git
(osd) $ cd umdone
(osd) $ pip install --no-deps .
```

OK! Now we are ready to start releasing episodes!

## Releasing an episode

**Step 1:** The first step in releasing an episode is to write the show
notes. Go into the `episodes/` directory and copy the temnplate to a
file with the project name, open the new file, and edit the details.
Then commit it and push up!

```sh
(osd) $ cd episodes
(osd) $ cp TEMPLATE.yaml <proj>.yaml
(osd) $ # edit <proj>.yaml
(osd) $ git add <proj>.yaml
(osd) $ git commit -am "added metadata for <proj>"
(osd) $ git push
```