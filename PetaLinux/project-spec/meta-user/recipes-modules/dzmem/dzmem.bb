SUMMARY = "dzmem: the DEBAZAROS video-slot region mapped cached, cache sync by range"
DESCRIPTION = "ROADMAP.md section 19 step 5, sw/SLOTMEM.md. /dev/dzmem maps the \
reserved slot region (0x0800_0000, 96 MB) with a chosen memory type (write-back, \
write-combine, uncached; write-through only with allow_wt) and cleans / \
invalidates the caches for a range on request. Version 2 (2026-11-21): one \
memory class per slot, counted, flush on the last cached close; module \
parameter guard (0 = mixes allowed and logged, 1 = refused). In the image \
and loaded at boot since 2026-11-21 (debaz-sw RDEPENDS): libdz uses it when \
/dev/dzmem is there; DZ_DZMEM=0 in debazd's environment = the old uncached \
/dev/mem path."
SECTION = "PETALINUX/modules"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://COPYING;md5=12f884d2ae1ff87c09e5b7ccc2c4ca7e"

inherit module

# the ioctl header is shared with user space: the repo's sw/include/dzmem.h
FILESEXTRAPATHS:prepend := "${THISDIR}/../../../../..:"

SRC_URI = "file://Makefile \
           file://dzmem.c \
           file://COPYING \
           file://99-dzmem.rules \
           file://sw/include/dzmem.h \
          "

S = "${WORKDIR}"

# load at boot (/etc/modules-load.d/dzmem.conf); no DT node
KERNEL_MODULE_AUTOLOAD += "dzmem"

do_install:append() {
	install -d ${D}${sysconfdir}/udev/rules.d
	install -m 0644 ${WORKDIR}/99-dzmem.rules ${D}${sysconfdir}/udev/rules.d/
}
FILES:${PN} += "${sysconfdir}/udev/rules.d/99-dzmem.rules"
