SUMMARY = "DEBAZAROS software: debazd, dzctl, dzweb + web app, hdmi2, fbfeed, dzmosh, tools, bring-up at boot"
DESCRIPTION = "Builds the repo's sw/ with the Yocto cross compiler (plain Makefiles, \
make image-install) and adds the bitstreams the software expects. debaz.service \
runs dzstart.sh at boot. A development copy from `make -C sw install` \
(/home/ebaz/bin, /home/ebaz/www) still wins over these files (sw/lib/dz_path.h)."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# The source is the repo itself (as debaz-firstboot): sw/ and the
# hardware-tested bitstreams in artifacts/. A rebuild picks up the checked-out
# tree; bitbake hashes every file, so a change in sw/ rebuilds the package.
FILESEXTRAPATHS:prepend := "${THISDIR}/../../../../..:"

# BOOT.BIN carries the bitstream of the project's XSA. These go to
# /lib/firmware for plreload.sh / dzstart.sh BITSTREAM (the first = the
# current design, the others = fallbacks). sw/include/hw_map.h must match
# the BOOT.BIN design.
DEBAZ_BITSTREAMS ?= "ebaz4205_2out1in_20261101_sdly.bit.bin ebaz4205_2out1in_20261029_osc_epo.bit.bin"

SRC_URI = "file://sw \
           ${@' '.join('file://artifacts/' + b for b in d.getVar('DEBAZ_BITSTREAMS').split())} \
          "

S = "${WORKDIR}/sw"

inherit systemd

SYSTEMD_SERVICE:${PN} = "debaz.service"
SYSTEMD_AUTO_ENABLE = "enable"

# common.mk keeps CC/AR from the environment (Yocto's, with --sysroot and
# the Cortex-A9 flags) and the link lines use LDFLAGS (GNU hash QA).
do_compile() {
	oe_runmake clean		# a copied out/ from a laptop build must not count
	oe_runmake all
}

do_install() {
	oe_runmake image-install DESTDIR=${D}
	install -d ${D}${nonarch_base_libdir}/firmware
	for b in ${DEBAZ_BITSTREAMS}; do
		install -m 0644 ${WORKDIR}/artifacts/$b ${D}${nonarch_base_libdir}/firmware/
	done
}

FILES:${PN} += "${datadir}/debaz ${sysconfdir}/debaz ${systemd_system_unitdir}/debaz.service \
                ${nonarch_base_libdir}/firmware"
CONFFILES:${PN} = "${sysconfdir}/debaz/dzstart.conf"

# ffmpeg/ffprobe (movies, images), arecord (in -aplay)/amixer/alsactl (audio, react.c,
# plreload), setpriv (dzweb as ebaz), fonts for the TrueType text
# (sw/lib/dz_text.c: LiberationSans-Regular.ttf default, DejaVu fallbacks)
RDEPENDS:${PN} += "ffmpeg alsa-utils-aplay alsa-utils-amixer alsa-utils-alsactl \
                   util-linux-setpriv liberation-fonts ttf-dejavu-sans \
                   ttf-dejavu-sans-mono ttf-dejavu-serif debaz-firstboot"
# image decoders for the image-sequence player (ROADMAP.md section 16):
# TurboJPEG (NEON) and libpng (simplified API). debazd opens them with
# dlopen (the Vitis toolchain has no headers), so the shlib scan does not
# see them: name them here. Both were already in the 2026-11-01 sandbox
# image (libpng only through freetype).
RDEPENDS:${PN} += "libturbojpeg libpng"

# bitstreams are data, not ELF for this machine
INSANE_SKIP:${PN} += "arch"
