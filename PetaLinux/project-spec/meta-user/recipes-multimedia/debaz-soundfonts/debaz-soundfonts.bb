SUMMARY = "General MIDI soundfont for fluidsynth (TimGM6mb, 6 MB)"
DESCRIPTION = "TimGM6mb.sf2 by Tim Brechbill (the Debian timgm6mb-soundfont source), \
installed as /usr/share/soundfonts/TimGM6mb.sf2 with default.sf2 -> it (fluidsynth's \
default soundfont path). Small enough for the root fs; larger soundfonts (e.g. \
FluidR3_GM, 141 MB) go to the media partition: /media/debaz/soundfonts."
HOMEPAGE = "https://packages.debian.org/source/sid/timgm6mb-soundfont"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

# snapshot.debian.org by SHA-1: a permanent address (the Debian pool drops old
# versions); the same file as pool/main/t/timgm6mb-soundfont/timgm6mb-soundfont_1.3.orig.tar.gz
SRC_URI = "https://snapshot.debian.org/file/2ba5e0070863970055c74d5a8ed84538e14f6124;downloadfilename=timgm6mb-soundfont_1.3.orig.tar.gz"
SRC_URI[sha256sum] = "af8f3a00e416dfb262bcaa904a1c84df04a51b72bbc1313aed012bc754bdf99b"

S = "${WORKDIR}/timgm6mb-soundfont_1.3"

inherit allarch

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
	install -d ${D}${datadir}/soundfonts
	install -m 0644 ${S}/TimGM6mb.sf2 ${D}${datadir}/soundfonts/
	ln -sf TimGM6mb.sf2 ${D}${datadir}/soundfonts/default.sf2
}

FILES:${PN} = "${datadir}/soundfonts"
