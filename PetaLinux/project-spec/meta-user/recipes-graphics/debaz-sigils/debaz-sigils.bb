SUMMARY = "DEBAZAROS sprite sigils: the 73 Goetia seals as 256 x 256 white-on-alpha PNGs"
DESCRIPTION = "The processed sprites of the repo's sigils/ folder (sigil-NN-name.png, \
see sigils/README.md) in /usr/share/debaz/img. debaz-firstboot copies them once \
into the media folder /media/debaz/img (missing names only), where /sprite/<id>/load \
and /draw/<s>/img find them."
# Wikimedia Commons, credited to S.L. MacGregor Mathers and Aleister Crowley
# (1904): public domain
LICENSE = "CLOSED"

# the source is the repo itself (as debaz-sw): ../../../../.. = the repo root
FILESEXTRAPATHS:prepend := "${THISDIR}/../../../../..:"
SRC_URI = "file://sigils"
S = "${WORKDIR}/sigils"

inherit allarch

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
	install -d ${D}${datadir}/debaz/img
	install -m 0644 ${S}/sigil-*.png ${S}/README.md ${D}${datadir}/debaz/img/
}

FILES:${PN} = "${datadir}/debaz/img"
