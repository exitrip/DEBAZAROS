SUMMARY = "DEBAZAROS fonts: text in many scripts + display fonts for debazd's TrueType text"
DESCRIPTION = "The set that sw/tools/pushfonts.sh puts on a unit, in \
/usr/share/fonts/debaz (debazd DZ_FONT_DIR = /usr/share/fonts and its \
subfolders; sw/lib/dz_text.c picks a script font by Unicode block): DejaVu, \
Free*, Liberation Mono/Serif, Droid Sans Fallback (CJK), Lohit (Indic), a \
Hangul subset of Noto Sans CJK KR, Thai/Lao/Tibetan/Myanmar/Ethiopic/Khmer/ \
Sinhala/Arabic fonts, 731 Typodermic public-domain fonts and Pastor of Muppets \
in typodermic/. Each package's licence is in /usr/share/fonts/debaz/LICENSES."
# Source = a tarball made on the laptop (Debian font packages + the two
# Typodermic zips):  bash sw/tools/pushfonts.sh -o \
#   PetaLinux/project-spec/meta-user/recipes-graphics/debaz-fonts/files/debaz-fonts.tar.gz
# It is git-ignored (32 MB): copy it with the tree to the build machine.
# Licences (per file, LICENSES/): SIL OFL 1.1, GPL-3+ with font exception,
# Apache 2.0, Bitstream Vera, CC0 (Typodermic), Larabie freeware (Pastor of
# Muppets: no licence text). No one licence fits the set, so the license
# check is skipped; the texts go into the package.
LICENSE = "CLOSED"

SRC_URI = "file://debaz-fonts.tar.gz;subdir=fonts"
S = "${WORKDIR}/fonts"

inherit allarch fontcache

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
	install -d ${D}${datadir}/fonts/debaz
	cp -R --no-preserve=ownership ${S}/. ${D}${datadir}/fonts/debaz/
	find ${D}${datadir}/fonts/debaz -type d -exec chmod 0755 {} +
	find ${D}${datadir}/fonts/debaz -type f -exec chmod 0644 {} +
}

FILES:${PN} = "${datadir}/fonts/debaz"
