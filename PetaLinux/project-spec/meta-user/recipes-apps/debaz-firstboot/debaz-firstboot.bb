SUMMARY = "DEBAZAROS first boot: data + exFAT media partitions, media folders, per-card MAC and hostname"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# the script lives in the repo's sw/tools (one copy for the image and
# for `make -C sw install`)
FILESEXTRAPATHS:prepend := "${THISDIR}/../../../../../sw/tools:"

SRC_URI = "file://debaz-mac.sh \
           file://debaz-firstboot.sh \
           file://debaz-firstboot.service \
          "

S = "${WORKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "debaz-firstboot.service"
SYSTEMD_AUTO_ENABLE = "enable"

do_install() {
	install -d ${D}${sbindir} ${D}${systemd_system_unitdir}
	install -m 0755 ${WORKDIR}/debaz-mac.sh ${D}${sbindir}/debaz-mac.sh
	install -m 0755 ${WORKDIR}/debaz-firstboot.sh ${D}${sbindir}/debaz-firstboot.sh
	install -d ${D}/media/debaz
	install -m 0644 ${WORKDIR}/debaz-firstboot.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${systemd_system_unitdir}/debaz-firstboot.service /media/debaz"
# sfdisk, partx, blkid (util-linux), mkfs.ext4 (e2fsprogs), mkfs.exfat (exfat-utils)
RDEPENDS:${PN} += "util-linux-sfdisk util-linux-partx util-linux-blkid util-linux-blockdev util-linux-mountpoint e2fsprogs-mke2fs exfat-utils"
