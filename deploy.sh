#!/usr/bin/env bash

set -euxo pipefail

tmpDir=$(mktemp -d)
function cleanup() {
	rm -rf "$tmpDir"
}
trap cleanup EXIT

nix build
blogRelease=$(readlink result)

git clone --depth 1 git@github.com:tfc/tfc.github.io.git "$tmpDir"

cd "$tmpDir"
git checkout master

cp -r "$blogRelease"/* .

chmod -R 755 .
touch .nojekyll

# Commit
git add -A
git commit -m "Publish."

# Push
git push origin master:master
