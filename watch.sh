#!/usr/bin/env bash

set -euo pipefail

cabal build
cabal exec blog-generator clean
cabal exec blog-generator watch
