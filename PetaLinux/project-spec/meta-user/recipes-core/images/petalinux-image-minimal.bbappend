# Passwordless sudo for the ebaz user (2026-10-28): the board tools
# (plreload.sh, pcmplay, avplay.sh, lrtest.sh) and remote scripts run
# "sudo" without a terminal. CONFIG_ADD_USERS_TO_SUDOERS only adds ebaz with
# a password. Same rule as the hand-edited card before the Oct 28 image.
ROOTFS_POSTPROCESS_COMMAND:append = " ebaz_sudo_nopasswd;"

ebaz_sudo_nopasswd() {
	install -d -m 0750 ${IMAGE_ROOTFS}${sysconfdir}/sudoers.d
	echo 'ebaz ALL=(ALL) NOPASSWD: ALL' > ${IMAGE_ROOTFS}${sysconfdir}/sudoers.d/ebaz
	chmod 0440 ${IMAGE_ROOTFS}${sysconfdir}/sudoers.d/ebaz
}
