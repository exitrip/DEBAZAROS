#!/bin/sh
# mkmovie.sh - replaced by mkmedia.sh (2026-10-28): movies, audio and images,
# files or folders, output in img/ movies/ audio/ like the board.
#   bash sw/tools/mkmedia.sh [options] FILE|FOLDER ...   (-h: all options)
# The old second argument (output file name) is gone: output goes to -o DIR.
echo "mkmovie.sh: use mkmedia.sh (running it now)" >&2
exec bash "$(dirname "$0")/mkmedia.sh" "$@"
