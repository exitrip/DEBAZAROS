#!/bin/bash
# pushfonts.sh - copy a set of free fonts from THIS machine (Ubuntu/Debian font
# packages) to a board's font folder (2026-11-01). The Oct 28 image has no
# font package; debazd's TrueType text and the ASCII "chars" mode read
# DZ_FONT_DIR = /usr/share/fonts (and its subfolders).
#
#   bash sw/tools/pushfonts.sh [-u ebaz@host]     (default: $DZ_BOARD)
#
# The set (with the licence file of each package, into
# /usr/share/fonts/debaz/LICENSES/):
#   DejaVu Sans / Sans Mono / Serif   Bitstream Vera licence   dingbats ✫ ✌,
#                                     braille, box drawing, symbols
#   FreeSans / FreeSerif / FreeMono   GPL-3+ with font exception   wide cover
#   Liberation Mono / Serif           SIL OFL 1.1 (Sans is on the image)
#   Droid Sans Fallback Full          Apache 2.0   CJK, katakana (4 MB)
# Packages: fonts-dejavu-core fonts-freefont-ttf fonts-liberation
# fonts-droid-fallback. debazd loads a whole font file into RAM, so the 19 MB
# Noto CJK collection is left out.
set -euo pipefail

board=${DZ_BOARD:-}
while getopts "u:h" o; do
	case $o in
	u) board=$OPTARG ;;
	*) sed -n '2,18p' "$0"; exit 2 ;;
	esac
done
[ -n "$board" ] || { echo "pushfonts: no board: -u ebaz@host or DZ_BOARD" >&2; exit 2; }

F=/usr/share/fonts/truetype
fonts=(
	$F/dejavu/DejaVuSans.ttf $F/dejavu/DejaVuSansMono.ttf $F/dejavu/DejaVuSerif.ttf
	$F/freefont/FreeSans.ttf $F/freefont/FreeSerif.ttf $F/freefont/FreeMono.ttf
	$F/liberation/LiberationMono-Regular.ttf $F/liberation/LiberationSerif-Regular.ttf
	$F/droid/DroidSansFallbackFull.ttf
)
lic=(fonts-dejavu-core fonts-freefont-ttf fonts-liberation fonts-droid-fallback)

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/LICENSES"
for f in "${fonts[@]}"; do
	[ -r "$f" ] || { echo "pushfonts: missing $f (install its package)" >&2; exit 1; }
	cp "$f" "$stage/"
done
for p in "${lic[@]}"; do
	cp "/usr/share/doc/$p/copyright" "$stage/LICENSES/$p.txt"
done

opt=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5)
ssh_() { sshpass -p '' ssh "${opt[@]}" "$board" "$@"; }
echo "pushfonts: $(du -sh "$stage" | cut -f1) to $board:/usr/share/fonts/debaz"
ssh_ 'rm -rf /tmp/dz-fonts && mkdir -p /tmp/dz-fonts'
tar -C "$stage" -cf - . | ssh_ 'tar -C /tmp/dz-fonts -xf - &&
	sudo mkdir -p /usr/share/fonts/debaz &&
	sudo cp -r /tmp/dz-fonts/. /usr/share/fonts/debaz/ && rm -rf /tmp/dz-fonts &&
	ls /usr/share/fonts/debaz'
