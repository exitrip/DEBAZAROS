# No PulseAudio on the unit (decision 2026-10-28, ROADMAP.md section 13).
# The distro has the pulseaudio feature, so alsa-plugins builds the pulse
# plugin, and 99-pulseaudio-default.conf made "pulse" the default ALSA
# device (amixer / aplay without -c/-D: "Connection refused": no server).
# PACKAGECONFIG:remove = "pulseaudio" does not work: other image packages
# pull in pulseaudio, which needs alsa-plugins-pulseaudio-conf. So only the
# default-device file goes; /etc/asound.conf (debaz-audio) sets the default.
do_install:append() {
	rm -f ${D}${datadir}/alsa/alsa.conf.d/99-pulseaudio-default.conf \
	      ${D}${sysconfdir}/alsa/conf.d/99-pulseaudio-default.conf
}
