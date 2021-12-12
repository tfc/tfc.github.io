#!/usr/bin/env bash

set -euo pipefail

git stash

git checkout develop

"$(nix-build --no-out-path)/bin/blog-generator" build

# Get previous files
git fetch --all
git checkout -b master --track origin/master

cp -r _site/* .
rm result

# Commit
git add -A
git commit -m "Publish."

# Push
git push origin master:master

# Restoration
git checkout develop
git branch -D master
git stash pop
