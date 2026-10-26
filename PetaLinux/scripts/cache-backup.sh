#!/bin/bash
# cache-backup.sh - copy build/downloads (without the git2/ bare clones: a
# git2_*.tar.gz mirror tarball exists for each) and build/sstate-cache to
# $PLNX_CACHE. Then copy $PLNX_CACHE to another disk.
source "$(dirname "$0")/common.sh"
P=$PLNX_PROJECT/build
mkdir -p "$PLNX_CACHE"
rsync -a --exclude "/git2/" --exclude "*.lock" "$P/downloads/" "$PLNX_CACHE/downloads/" || exit 1
rsync -a "$P/sstate-cache/" "$PLNX_CACHE/sstate-cache/" || exit 1
du -sh "$PLNX_CACHE/downloads" "$PLNX_CACHE/sstate-cache"
