#!/bin/bash

git stash

git checkout develop

stack build
stack exec site clean
stack exec site build

# Get previous files
git fetch --all
git checkout -b master --track origin/master

find . -type d -depth 1 -not -name ".*" -and -not -name "_site" -exec rm -r {} \;
mv _site/* .

# Commit
git add -A
git commit -m "Publish."

# Push
git push origin master:master

# Restoration
git checkout develop
git branch -D master
git stash pop
