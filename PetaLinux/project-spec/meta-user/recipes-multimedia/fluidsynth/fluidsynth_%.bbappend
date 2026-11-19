# DEBAZAROS (2026-11-20): ALSA only. The distro has pulseaudio in
# DISTRO_FEATURES, so the recipe's default PACKAGECONFIG linked
# libpulse-simple (PulseAudio is not in the image and not wanted: fluidsynth
# plays straight to the DEBAZ ALSA card, MIDI in through the ALSA sequencer).
PACKAGECONFIG:remove = "pulseaudio"
