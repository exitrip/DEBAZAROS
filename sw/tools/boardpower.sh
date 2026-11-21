#!/bin/bash
# boardpower.sh - reboot and power-cycle a bench board from the laptop
# (2026-11-21). The board takes its 5 V from a laptop USB-C connector, and its
# UART console (ttyPS0) is a CH340 adapter on the same connector.
#
#   boardpower.sh install            detect the connector, print the sudo
#                                    commands that install the root helper
#   boardpower.sh status             ping, ssh, serial, USB-C state
#   boardpower.sh log start|stop|tail [n]|path
#                                    serial console logger (background, time
#                                    stamps, survives the adapter going away
#                                    during a power cut)
#   boardpower.sh reboot [-H|-S]     the gentlest way that works: ssh "sudo
#                                    reboot", else a login on the serial
#                                    console, else a power cycle; -S = start
#                                    with the serial console (sshd stuck),
#                                    -H = power cycle at once. Waits until
#                                    ssh answers.
#   boardpower.sh cycle [secs] [xhci|ucsi]   power cycle only (helper)
#   boardpower.sh wait-up [secs]     wait until ssh answers (default 120)
#   boardpower.sh console            interactive console (screen; stops the
#                                    logger while it runs)
#
# Environment: DZ_BOARD (ebaz@10.42.0.236), DZ_SERIAL (the CH340 by-id path),
# DZ_POWER_METHOD (ucsi: USB-C hard reset, measured to power-cycle .236;
# xhci: USB port power off, does NOT cut the 5 V of a USB-C port here),
# DZ_SERLOG (~/debaz-serial/<host>.log). A power cut can damage the SD card
# file systems: it is the last step, and every use is logged.
set -uo pipefail

BOARD=${DZ_BOARD:-ebaz@10.42.0.236}
HOST=${BOARD#*@}
SERIAL=${DZ_SERIAL:-/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0}
LOGDIR=${DZ_SERLOG_DIR:-$HOME/debaz-serial}
SERLOG=${DZ_SERLOG:-$LOGDIR/$HOST.log}
PIDF=$LOGDIR/.logger-$HOST.pid
HELPER=/usr/local/sbin/dz-usbpower
# ucsi = USB-C connector hard reset: the only way that cuts the 5 V on this
# laptop (2026-11-21: xhci port power off drops the USB link, VBUS stays)
METHOD=${DZ_POWER_METHOD:-ucsi}
HERE=$(cd "$(dirname "$0")" && pwd)

mkdir -p "$LOGDIR"
O=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=3)
ssh_() { sshpass -p '' ssh "${O[@]}" "$BOARD" "$@"; }
note() { printf '%(%F %T)T boardpower: %s\n' -1 "$*" | tee -a "$SERLOG" >&2; }
alive() { ssh_ true 2>/dev/null; }
pinged() { ping -c1 -W1 "$HOST" >/dev/null 2>&1; }

logger_running() { [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; }

log_start() {
	logger_running && return 0
	# one reader of the tty; reopens after the adapter comes back
	setsid "$HERE/$(basename "$0")" _logger < /dev/null > /dev/null 2>&1 &
	echo $! > "$PIDF"
	note "serial logger started (pid $!, $SERLOG)"
}

log_stop() {
	logger_running || { rm -f "$PIDF"; return 0; }
	local p; p=$(cat "$PIDF")
	kill -- -"$p" 2>/dev/null || kill "$p"	# its own session: the loop + the reader
	rm -f "$PIDF"
	note "serial logger stopped (pid $p)"
}

# the logger process: one reader of the tty, reopened after the adapter comes
# back; a line without a newline (a login prompt) is written after 0.3 s
logger_loop() {
	local l rc
	trap '' HUP	# the tty hangs up when the adapter loses power: keep going
	while :; do
		if [ -e "$SERIAL" ] && stty -F "$SERIAL" 115200 raw -echo -hupcl 2>/dev/null &&
		   exec 3< "$SERIAL"; then
			while :; do
				l=; IFS= read -r -t 0.3 -u 3 l; rc=$?
				l=${l//$'\r'/}
				if [ $rc = 0 ] || [ -n "$l" ]; then
					printf '%(%F %T)T %s\n' -1 "$l" >> "$SERLOG"
				fi
				[ $rc = 0 ] || [ $rc -gt 128 ] || break	# EOF / error: reopen
			done
			exec 3<&-
		fi
		sleep 0.5
	done
}

ser_send() { [ -e "$SERIAL" ] && printf '%b' "$1" > "$SERIAL"; }

# wait up to $2 s for regex $1 in log lines written after byte offset $3
ser_wait() {
	local re=$1 t=$2 from=$3 i
	for ((i = 0; i < t * 2; i++)); do
		tail -c +"$((from + 1))" "$SERLOG" 2>/dev/null | grep -Eq "$re" && return 0
		sleep 0.5
	done
	return 1
}

wait_up() {
	local t=${1:-120} i
	for ((i = 0; i < t; i++)); do
		alive && { note "board up (ssh) after ${i}s"; return 0; }
		sleep 1
	done
	note "board NOT up after ${t}s"
	return 1
}

wait_down() {	# ping stops answering within $1 s
	local i
	for ((i = 0; i < $1; i++)); do pinged || return 0; sleep 1; done
	return 1
}

cycle() {
	[ -x "$HELPER" ] || { echo "boardpower: no $HELPER: run '$0 install' first" >&2; return 1; }
	note "POWER CYCLE ${2:-$METHOD} (${1:-3}s for xhci)"
	sudo -n "$HELPER" cycle "${1:-3}" "${2:-$METHOD}" 2>&1 | tee -a "$SERLOG"
}

serial_reboot() {	# log in on the console (ebaz) if needed, then sudo reboot
	local off prompt='[$#] *$'
	log_start
	off=$(stat -c %s "$SERLOG")
	ser_send '\r'
	ser_wait "login:|$prompt" 3 "$off" || return 1
	if ! tail -c +"$((off + 1))" "$SERLOG" | grep -Eq "$prompt"; then
		off=$(stat -c %s "$SERLOG")
		ser_send 'ebaz\r'
		ser_wait "assword|$prompt" 10 "$off" || return 1
		tail -c +"$((off + 1))" "$SERLOG" | grep -q assword && ser_send '\r'
		# the profile asks the terminal size (ESC[6n) first: wait for the prompt
		ser_wait "$prompt" 10 "$off" || return 1
	fi
	off=$(stat -c %s "$SERLOG")
	ser_send 'sudo reboot\r'
	ser_wait 'assword' 3 "$off" && ser_send '\r'
	wait_down 30
}

case ${1:-status} in
_logger) logger_loop ;;
install)
	dev=$(basename "$(readlink -f "$SERIAL")")
	d=$(readlink -f "/sys/class/tty/$dev/device/../..")	# the USB device
	[ -r "$d/idVendor" ] || { echo "boardpower: serial adapter $SERIAL not found" >&2; exit 1; }
	id=$(cat "$d/idVendor"):$(cat "$d/idProduct")
	tmp=$LOGDIR/dz-usbpower.install
	sed "s|^ADAPTER=.*|ADAPTER=$id	# vendor:product of the board's console adapter|" \
		"$HERE/dz-usbpower" > "$tmp"
	echo "console adapter $id (now $(basename "$d")); the helper finds its connector at every run"
	echo "Run these once (they need your password):"
	echo "  sudo install -o root -g root -m 0755 $tmp $HELPER"
	echo "  echo '$USER ALL=(root) NOPASSWD: $HELPER' | sudo tee /etc/sudoers.d/dz-usbpower >/dev/null"
	echo "  sudo chmod 0440 /etc/sudoers.d/dz-usbpower && sudo visudo -cf /etc/sudoers.d/dz-usbpower"
	;;
status)
	printf 'ping %s  ssh %s  serial %s  logger %s\n' \
		"$(pinged && echo up || echo DOWN)" "$(alive && echo up || echo DOWN)" \
		"$([ -e "$SERIAL" ] && echo present || echo ABSENT)" \
		"$(logger_running && echo "pid $(cat "$PIDF")" || echo off)"
	[ -x "$HELPER" ] && sudo -n "$HELPER" info 2>&1 || echo "helper: not installed ($0 install)"
	[ -s "$SERLOG" ] && { echo "serial log ($SERLOG), last lines:"; tail -n 3 "$SERLOG"; }
	;;
log)
	case ${2:-tail} in
	start) log_start ;;
	stop) log_stop ;;
	tail) tail -n "${3:-30}" "$SERLOG" ;;
	path) echo "$SERLOG" ;;
	*) echo "boardpower: log start|stop|tail [n]|path" >&2; exit 2 ;;
	esac ;;
reboot)
	log_start
	if [ "${2:-}" != -H ]; then
		if [ "${2:-}" != -S ] && alive; then
			note "reboot by ssh"
			ssh_ 'sudo systemctl reboot || sudo reboot' >/dev/null 2>&1
			wait_down 30 && { sleep 5; wait_up 150; exit $?; }
			note "ssh reboot did not take the board down"
		fi
		note "reboot by the serial console"
		serial_reboot && { sleep 5; wait_up 150 && exit 0; }
		note "serial reboot failed"
	fi
	cycle 3 && { sleep 5; wait_up 150; exit $?; }
	exit 1 ;;
cycle) log_start; cycle "${2:-3}" "${3:-}" ;;
wait-up) wait_up "${2:-120}" ;;
console)
	was=0; logger_running && { was=1; log_stop; }
	screen "$SERIAL" 115200
	[ $was = 1 ] && log_start ;;
*) sed -n '2,28p' "$0"; exit 2 ;;
esac
