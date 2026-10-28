# No PulseAudio on the unit (decision 2026-10-28, ROADMAP.md section 13):
# the distro has the pulseaudio feature, so alsa-plugins built the pulse
# plugin and 99-pulseaudio-default.conf, which made "pulse" the default
# ALSA device (amixer / aplay without -c/-D: "Connection refused"). Only
# this recipe changes; /etc/asound.conf (debaz-audio) sets the default.
PACKAGECONFIG:remove = "pulseaudio"
