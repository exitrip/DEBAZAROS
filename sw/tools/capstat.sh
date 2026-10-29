#!/bin/sh
# capstat.sh - HDMI_2 capture path status, for hot-plug debugging.
#
#   capstat.sh          one snapshot
#   capstat.sh -w [ms]  watch: print a line every sample (default 500 ms)
#
# Reads only, except the DMASR FrmCnt_Irq bit (W1C), which it clears to
# detect frame completions - the same thing hdmi2.elf CaptureInitialize does.
# Never writes DMACR, so it cannot halt the S2MM channel.
# While debazd runs (it holds an flock on /tmp/debazd.lock), capstat does NOT
# write DMASR: debazd clears the same bit every poll, so both would take each
# other's frame events (2026-10-29: capstat showed frm=0 at 1600x1200@30
# while the capture ran, and debazd saw gaps - after ~1 s without a frame
# it arms again with a soft reset). Then "frm" is debazd's frame state
# (/capture/status: a frame within the last ~100 ms), marked "frm(d)".
# IntErr/SOFLate after an arm are latches; debazd does not clear them.
#
# Columns:
#   pL aL      dvi2rgb pLocked / aLocked          (GPIO 0x41200000 [10]/[11])
#   ov un      v_vid_in_axi4s overflow/underflow  ([12]/[13])
#   DMACR      S2MM control  (0x43020030)  RS=bit0 RESET=bit2
#   DMASR      S2MM status   (0x43020034)  decoded in "err"
#   fc         IRQFrameCntSts DMASR[23:16]
#   frm        1 = a frame completed since last sample (FrmCnt_Irq relatch);
#              frm(d) = debazd's frame state (see above)
#   pix        checksum of 8 words spread over the capture frame; changes = live

DEVMEM=/sbin/devmem
GPIO=0x41200000
VDMA=0x43020000
SLOT=                      # capture frame address: read from S2MM frame store 0
FRAME_BYTES=               # stride x VSIZE of the S2MM setup
DZCTL=/home/ebaz/bin/dzctl
LOCK=/tmp/debazd.lock

rd() { $DEVMEM $1 32; }

# 0 = debazd runs (it holds its lock; without flock(1): pgrep)
debazd_running() {
	if command -v flock >/dev/null 2>&1; then
		[ -e $LOCK ] && ! flock -n -s $LOCK true
	else
		pgrep -x debazd >/dev/null
	fi
}

decode_sr() {
	sr=$(($1))
	s=""
	[ $((sr & 0x1))    -ne 0 ] && s="$s Halted"
	[ $((sr & 0x10))   -ne 0 ] && s="$s IntErr"
	[ $((sr & 0x20))   -ne 0 ] && s="$s SlvErr"
	[ $((sr & 0x40))   -ne 0 ] && s="$s DecErr"
	[ $((sr & 0x80))   -ne 0 ] && s="$s SOFEarly"
	[ $((sr & 0x100))  -ne 0 ] && s="$s EOLEarly"
	[ $((sr & 0x800))  -ne 0 ] && s="$s SOFLate"
	[ $((sr & 0x4000)) -ne 0 ] && s="$s ErrIrq"
	[ $((sr & 0x8000)) -ne 0 ] && s="$s EOLLate"
	echo "${s:- ok}"
}

pixsum() {
	[ -n "$SLOT" ] || SLOT=$(rd $((VDMA + 0xAC)))
	[ -n "$FRAME_BYTES" ] || FRAME_BYTES=$(( $(rd $((VDMA + 0xA8))) * $(rd $((VDMA + 0xA0))) ))
	sum=0
	i=0
	while [ $i -lt 8 ]; do
		a=$((SLOT + (FRAME_BYTES / 8) * i + 2560 * 4 * i))
		sum=$(( (sum + $(rd $(printf 0x%08x $a))) & 0xffffffff ))
		i=$((i + 1))
	done
	printf %08x $sum
}

sample() {
	g=$(($(rd $GPIO)))
	cr=$(rd $((VDMA + 0x30)))
	sr=$(rd $((VDMA + 0x34)))
	if [ $DEBAZD -eq 1 ]; then
		set -- $($DZCTL /capture/status 2>/dev/null)
		frm=${4:-?}
		ft="frm(d)"
	else
		frm=$(( ($sr >> 12) & 1 ))
		ft="frm"
		# clear FrmCnt_Irq so the next sample shows only new frames
		[ $frm -eq 1 ] && $DEVMEM $((VDMA + 0x34)) 32 0x00001000
	fi
	printf "%s  pL=%d aL=%d ov=%d un=%d  DMACR=%s DMASR=%s fc=%3d %s=%s pix=%s %s\n" \
		"$(date +%T)" \
		$(( (g >> 10) & 1 )) $(( (g >> 11) & 1 )) \
		$(( (g >> 12) & 1 )) $(( (g >> 13) & 1 )) \
		$cr $sr $(( ($sr >> 16) & 0xff )) $ft $frm "$(pixsum)" \
		"$(decode_sr $sr)"
}

DEBAZD=0
debazd_running && DEBAZD=1
if [ "$1" = "-w" ]; then
	ms=${2:-500}
	while true; do
		sample
		usleep $((ms * 1000)) 2>/dev/null || sleep 1
	done
else
	sample
	printf "VSIZE=%s HSIZE=%s STRIDE=%s ADDR1=%s PARK=%s\n" \
		$(rd $((VDMA + 0xA0))) $(rd $((VDMA + 0xA4))) \
		$(rd $((VDMA + 0xA8))) $(rd $((VDMA + 0xAC))) \
		$(rd $((VDMA + 0x28)))
fi
