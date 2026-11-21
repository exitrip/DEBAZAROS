SUMMARY = "dzmem: the DEBAZAROS video-slot region mapped cached, cache sync by range (EXPERIMENT)"
DESCRIPTION = "ROADMAP.md section 19 step 5. /dev/dzmem maps the reserved slot \
region (0x0800_0000, 96 MB) with a chosen memory type (write-back, write-through, \
write-combine, uncached) and cleans / invalidates the caches for a range on \
request. NOT in the image and NOT loaded at boot: build the package, push it \
to a unit (sw/tools/pkgpush.sh kernel-module-dzmem dzmem), insmod by hand, \
test with sw/tools/dzmemtest."
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

do_install:append() {
	install -d ${D}${sysconfdir}/udev/rules.d
	install -m 0644 ${WORKDIR}/99-dzmem.rules ${D}${sysconfdir}/udev/rules.d/
}
FILES:${PN} += "${sysconfdir}/udev/rules.d/99-dzmem.rules"
