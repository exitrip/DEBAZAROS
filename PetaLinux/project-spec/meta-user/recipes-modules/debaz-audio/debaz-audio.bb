SUMMARY = "ALSA card DEBAZ for the DEBAZAROS gateware PCM FIFOs (hdmi_audio_regs)"
SECTION = "PETALINUX/modules"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://COPYING;md5=12f884d2ae1ff87c09e5b7ccc2c4ca7e"

inherit module

SRC_URI = "file://Makefile \
           file://debaz-audio.c \
           file://COPYING \
          "

S = "${WORKDIR}"

# load at boot (the DT node binds it)
KERNEL_MODULE_AUTOLOAD += "debaz-audio"
