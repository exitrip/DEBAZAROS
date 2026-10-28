# Passwordless sudo for the ebaz user (2026-10-28): the board tools
# (plreload.sh, pcmplay, avplay.sh, lrtest.sh) and remote scripts run
# "sudo" without a terminal. CONFIG_ADD_USERS_TO_SUDOERS only adds ebaz with
# a password. Same rule as the hand-edited card before the Oct 28 image.
ROOTFS_POSTPROCESS_COMMAND:append = " ebaz_sudo_nopasswd; debaz_journald_runtime;"

ebaz_sudo_nopasswd() {
	install -d -m 0750 ${IMAGE_ROOTFS}${sysconfdir}/sudoers.d
	echo 'ebaz ALL=(ALL) NOPASSWD: ALL' > ${IMAGE_ROOTFS}${sysconfdir}/sudoers.d/ebaz
	chmod 0440 ${IMAGE_ROOTFS}${sysconfdir}/sudoers.d/ebaz
}

# The runtime journal (/run/log) took 16 MB of the 30 MB /run tmpfs (RAM:
# the board has 160 MB for Linux), and systemd then refuses daemon-reload
# ("safety buffer of 16.0M", 2026-10-28). 4 MB of log in RAM is enough.
debaz_journald_runtime() {
	install -d ${IMAGE_ROOTFS}${sysconfdir}/systemd/journald.conf.d
	printf '[Journal]\nRuntimeMaxUse=4M\n' > ${IMAGE_ROOTFS}${sysconfdir}/systemd/journald.conf.d/debaz.conf
}
