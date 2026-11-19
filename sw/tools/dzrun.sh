#!/bin/sh
# dzrun.sh video|debazd|dzweb|setup - the command of one DEBAZAROS systemd
# unit (2026-11-19). The units call /usr/bin/dzrun.sh; it picks the programs
# like the other tools: the dev copy in /home/ebaz/bin, else /usr/bin
# (sw/lib/dz_path.h), and the config like dzstart.sh.
#
#   video   debaz-video.service: hdmi2.elf with HDMI2_ARGS (config), or the
#           arguments debazd wrote for /video/mode (/run/debaz/video.args)
#   debazd  debazd.service (Restart=always)
#   dzweb   dzweb.service (User=ebaz)
#   setup   ExecStartPost of debazd.service: wait until debazd answers;
#           after a fresh PL (/run/debaz/fresh, written by dzstart.sh /
#           plreload.sh) the boot setup of the registers (dzsetup.sh) -
#           never after a plain debazd restart (it would undo the state)
D=${DZ_BIN:-/home/ebaz/bin}; [ -x "$D/debazd" ] || D=/usr/bin
# config: $DZSTART_CONF, else the card's on the data partition, else the
# old place in the home folder (root fs: read-only later), else the image's
CONF=${DZSTART_CONF:-/data/debaz/dzstart.conf}
[ -f "$CONF" ] || CONF=/home/ebaz/dzstart.conf
[ -f "$CONF" ] || CONF=/etc/debaz/dzstart.conf
HDMI2_ARGS="-r 1280x720"
# shellcheck disable=SC1090
[ -f "$CONF" ] && . "$CONF"
case ${1:-} in
video)
	[ -s /run/debaz/video.args ] && HDMI2_ARGS=$(cat /run/debaz/video.args)
	# shellcheck disable=SC2086
	exec "$D/hdmi2.elf" $HDMI2_ARGS ;;
debazd)
	exec "$D/debazd" -v ;;
dzweb)
	cd /home/ebaz 2>/dev/null || cd /
	exec "$D/dzweb" ;;
setup)
	i=0
	while [ $i -lt 50 ] && ! "$D/dzctl" -t 200 /ping > /dev/null 2>&1; do
		sleep 0.1
		i=$((i + 1))
	done
	if [ -f /run/debaz/fresh ]; then
		sh "$D/dzsetup.sh" && rm -f /run/debaz/fresh
		echo "dzrun: fresh PL: boot setup done (dzsetup.sh)"
	fi
	exit 0 ;;
*)
	echo "usage: dzrun.sh video|debazd|dzweb|setup" >&2
	exit 2 ;;
esac
