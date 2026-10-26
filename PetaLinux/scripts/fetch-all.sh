#!/bin/bash
# fetch-all.sh - download the source of EVERY recipe in the image, also of
# those a networked build takes ready-built from the AMD sstate feed (a
# backup without them failed an offline build, 2026-10-25: ethtool).
# Run with the network on, then scripts/cache-backup.sh.
source "$(dirname "$0")/common.sh"
( source "$(dirname "$0")/bitbake-env.sh" && bitbake petalinux-image-minimal --runall=fetch )
