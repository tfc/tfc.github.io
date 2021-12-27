#!/usr/bin/env bash

set -euxo pipefail

tmpDir=$(mktemp -d)
function cleanup() {
  rm -rf "$tmpDir"
}
trap cleanup EXIT

blogRelease=$(nix-build --no-out-link release.nix -A release)

git clone git@github.com:tfc/tfc.github.io.git "$tmpDir"

cd "$tmpDir"
git checkout master

rm -rf "$tmpDir/"*
cp -r "$blogRelease/"* .
chmod -R 755 .
touch .nojekyll

# Commit
git add -A
git commit -m "Publish."

# Push
git push origin master:master