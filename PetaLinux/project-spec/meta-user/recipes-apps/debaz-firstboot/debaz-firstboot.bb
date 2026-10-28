SUMMARY = "DEBAZAROS first boot: per-card MAC (from the SD card CID) and hostname"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# the script lives in the repo's sw/tools (one copy for the image and
# for `make -C sw install`)
FILESEXTRAPATHS:prepend := "${THISDIR}/../../../../../sw/tools:"

SRC_URI = "file://debaz-mac.sh \
           file://debaz-firstboot.service \
          "

S = "${WORKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "debaz-firstboot.service"
SYSTEMD_AUTO_ENABLE = "enable"

do_install() {
	install -d ${D}${sbindir} ${D}${systemd_system_unitdir}
	install -m 0755 ${WORKDIR}/debaz-mac.sh ${D}${sbindir}/debaz-mac.sh
	install -m 0644 ${WORKDIR}/debaz-firstboot.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${systemd_system_unitdir}/debaz-firstboot.service"
