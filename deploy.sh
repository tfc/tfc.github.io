#!/usr/bin/env bash

set -euo pipefail

git stash

git checkout develop

blogRelease=$(nix-build --no-out-link release.nix -A release)

# Get previous files
git fetch --all
git checkout -b master --track origin/master

git clean -xdf
cp -r "$blogRelease/*" .

# Commit
git add -A
git commit -m "Publish."

# Push
git push origin master:master

# Restoration
git checkout develop
git branch -D master
git stash pop
