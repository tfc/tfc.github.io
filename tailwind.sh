#!/usr/bin/env bash

set -euo pipefail

tailwindcss -c tailwind/tailwind.config.js -i tailwind/tailwind.css -o css/style.css $@
