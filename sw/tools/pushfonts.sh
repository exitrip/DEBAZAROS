#!/bin/bash
# pushfonts.sh - copy a set of free fonts from THIS machine (Ubuntu/Debian font
# packages) to a board's font folder (2026-11-01). The Oct 28 image has no
# font package; debazd's TrueType text and the ASCII "chars" mode read
# DZ_FONT_DIR = /usr/share/fonts (and its subfolders).
#
#   bash sw/tools/pushfonts.sh [-u ebaz@host]     (default: $DZ_BOARD)
#   bash sw/tools/pushfonts.sh -o fonts.tar.gz    the same set as a tarball
#        (2026-11-21) for the image recipe debaz-fonts: write it to
#        PetaLinux/project-spec/meta-user/recipes-graphics/debaz-fonts/files/
#        debaz-fonts.tar.gz (git-ignored, ~58 MB; copy it to the build machine)
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
# Scripts (2026-11-21; dz_text.c picks them by Unicode block when the chosen
# font lacks a glyph; Greek, Cyrillic, Armenian, Georgian, Hebrew, Arabic =
# DejaVu Sans / FreeSerif, kanji + kana = Droid Sans Fallback):
#   Lohit (OFL)          Devanagari Bengali Gurmukhi Gujarati Odia Tamil
#                        Telugu Kannada Malayalam
#   NotoSansKR-Hangul.otf  Hangul: made here from Noto Sans CJK KR (OFL) with
#                        fontTools subset (1.9 MB instead of 19 MB)
#   Loma (Thai) Phetsarath OT (Lao) Tibetan Machine Uni (4.4 MB) Padauk
#   (Myanmar) Abyssinica SIL (Ethiopic) Khmer OS LKLUG (Sinhala)
#   KacstOne (Arabic, by name only)
# Extra packages: fonts-lohit-* fonts-noto-cjk fonts-tlwg-loma-ttf fonts-lao
# fonts-tibetan-machine fonts-sil-padauk fonts-sil-abyssinica
# fonts-khmeros-core fonts-lklug-sinhala fonts-kacst-one, python3-fonttools.
# Display fonts by Ray Larabie (2026-11-21), from zips when they are there
# (else skipped with a note), into /usr/share/fonts/debaz/typodermic/:
#   $DZ_TYPODERMIC_ZIP (default ~/Downloads/typodermic-public-domain-2024-12.zip)
#                        731 OpenType fonts, CC0 public domain (License.txt
#                        goes along), ~37 MB
#   $DZ_PASTOR_ZIP (default ~/Downloads/pastor-of-muppets.zip)
#                        Pastor of Muppets + Flipped, Larabie freeware (no
#                        licence file in the zip)
# File names are made safe for debazd (letters, digits, . _ -): spaces ->
# "-", other characters dropped ("Bailey's Car.otf" -> Baileys-Car.otf).
set -euo pipefail

board=${DZ_BOARD:-}
out=
while getopts "u:o:h" o; do
	case $o in
	u) board=$OPTARG ;;
	o) out=$OPTARG ;;
	*) sed -n "2,46p" "$0"; exit 2 ;;
	esac
done
[ -n "$board" ] || [ -n "$out" ] || { echo "pushfonts: no board: -u ebaz@host or DZ_BOARD" >&2; exit 2; }

F=/usr/share/fonts/truetype
fonts=(
	$F/dejavu/DejaVuSans.ttf $F/dejavu/DejaVuSansMono.ttf $F/dejavu/DejaVuSerif.ttf
	$F/freefont/FreeSans.ttf $F/freefont/FreeSerif.ttf $F/freefont/FreeMono.ttf
	$F/liberation/LiberationMono-Regular.ttf $F/liberation/LiberationSerif-Regular.ttf
	$F/droid/DroidSansFallbackFull.ttf
	$F/lohit-devanagari/Lohit-Devanagari.ttf $F/lohit-bengali/Lohit-Bengali.ttf
	$F/lohit-punjabi/Lohit-Gurmukhi.ttf $F/lohit-gujarati/Lohit-Gujarati.ttf
	$F/lohit-oriya/Lohit-Odia.ttf $F/lohit-tamil/Lohit-Tamil.ttf
	$F/lohit-telugu/Lohit-Telugu.ttf $F/lohit-kannada/Lohit-Kannada.ttf
	$F/lohit-malayalam/Lohit-Malayalam.ttf
	$F/tlwg/Loma.ttf $F/lao/Phetsarath_OT.ttf $F/tibetan-machine/TibetanMachineUni.ttf
	$F/padauk/Padauk-Regular.ttf $F/abyssinica/AbyssinicaSIL-Regular.ttf
	$F/ttf-khmeros-core/KhmerOS.ttf $F/sinhala/lklug.ttf $F/kacst-one/KacstOne.ttf
)
lic=(fonts-dejavu-core fonts-freefont-ttf fonts-liberation fonts-droid-fallback
	fonts-lohit-deva fonts-lohit-beng-bengali fonts-lohit-guru fonts-lohit-gujr
	fonts-lohit-orya fonts-lohit-taml fonts-lohit-telu fonts-lohit-knda
	fonts-lohit-mlym fonts-tlwg-loma-ttf fonts-lao fonts-tibetan-machine
	fonts-sil-padauk fonts-sil-abyssinica fonts-khmeros-core fonts-lklug-sinhala
	fonts-kacst-one fonts-noto-cjk)
cjk=/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc	# face 1 = KR
typo_zip=${DZ_TYPODERMIC_ZIP:-$HOME/Downloads/typodermic-public-domain-2024-12.zip}
pastor_zip=${DZ_PASTOR_ZIP:-$HOME/Downloads/pastor-of-muppets.zip}

# unzip the fonts of zip $1 into folder $2 with safe names (debazd's
# font_name_ok); a name taken twice is an error
unzip_fonts() {
	local zip=$1 dst=$2 tmp f n
	tmp=$(mktemp -d -p "$stage")
	unzip -q "$zip" -d "$tmp"
	mkdir -p "$dst"
	while IFS= read -r -d '' f; do
		n=$(basename "$f" | sed 's/ /-/g; s/[^A-Za-z0-9._-]//g')
		[ -e "$dst/$n" ] && { echo "pushfonts: two fonts named $n in $zip" >&2; exit 1; }
		cp "$f" "$dst/$n"
	done < <(find "$tmp" -type f \( -iname '*.otf' -o -iname '*.ttf' \) -print0)
	rm -rf "$tmp"
}

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/LICENSES"
for f in "${fonts[@]}"; do
	[ -r "$f" ] || { echo "pushfonts: missing $f (install its package)" >&2; exit 1; }
	cp "$(readlink -f "$f")" "$stage/$(basename "$f")"
done
# Hangul only (jamo, compatibility jamo, syllables, CJK punctuation, full width)
[ -r "$cjk" ] || { echo "pushfonts: missing $cjk (fonts-noto-cjk)" >&2; exit 1; }
python3 -I -m fontTools.subset "$cjk" --font-number=1 --layout-features='*' \
	--unicodes=1100-11FF,3000-303F,3130-318F,A960-A97F,AC00-D7FF,FF00-FFEF \
	--output-file="$stage/NotoSansKR-Hangul.otf"
if [ -r "$typo_zip" ]; then
	unzip_fonts "$typo_zip" "$stage/typodermic"
	unzip -p "$typo_zip" License.txt > "$stage/LICENSES/typodermic-public-domain-CC0.txt"
else
	echo "pushfonts: no $typo_zip: Typodermic fonts skipped"
fi
if [ -r "$pastor_zip" ]; then
	unzip_fonts "$pastor_zip" "$stage/typodermic"
	echo "Pastor of Muppets (Ray Larabie, 1997): freeware, no licence file in the zip" \
		> "$stage/LICENSES/pastor-of-muppets.txt"
else
	echo "pushfonts: no $pastor_zip: Pastor of Muppets skipped"
fi
for p in "${lic[@]}"; do
	cp "/usr/share/doc/$p/copyright" "$stage/LICENSES/$p.txt"
done

if [ -n "$out" ]; then
	# fixed owner, mode and time: the same fonts give the same tarball
	tar -C "$stage" --sort=name --owner=0 --group=0 --numeric-owner \
		--mode='u=rwX,go=rX' --mtime='2026-11-21 00:00Z' -cf - . | gzip -n > "$out"
	echo "pushfonts: $(find "$stage" -type f | wc -l) files, $(du -h "$out" | cut -f1) -> $out"
	exit 0
fi
opt=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5)
ssh_() { sshpass -p '' ssh "${opt[@]}" "$board" "$@"; }
echo "pushfonts: $(du -sh "$stage" | cut -f1) to $board:/usr/share/fonts/debaz"
ssh_ 'rm -rf /tmp/dz-fonts && mkdir -p /tmp/dz-fonts'
tar -C "$stage" -cf - . | ssh_ 'tar -C /tmp/dz-fonts -xf - &&
	sudo mkdir -p /usr/share/fonts/debaz &&
	sudo cp -r /tmp/dz-fonts/. /usr/share/fonts/debaz/ && rm -rf /tmp/dz-fonts &&
	ls /usr/share/fonts/debaz'
