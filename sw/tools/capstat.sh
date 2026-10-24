#!/bin/sh
# capstat.sh - HDMI_2 capture path status, for hot-plug debugging.
#
#   capstat.sh          one snapshot
#   capstat.sh -w [ms]  watch: print a line every sample (default 500 ms)
#
# Reads only, except the DMASR FrmCnt_Irq bit (W1C), which it clears to
# detect frame completions - the same thing hdmi2.elf CaptureInitialize does.
# Never writes DMACR, so it cannot halt the S2MM channel.
#
# Columns:
#   pL aL      dvi2rgb pLocked / aLocked          (GPIO 0x41200000 [10]/[11])
#   ov un      v_vid_in_axi4s overflow/underflow  ([12]/[13])
#   DMACR      S2MM control  (0x43020030)  RS=bit0 RESET=bit2
#   DMASR      S2MM status   (0x43020034)  decoded in "err"
#   fc         IRQFrameCntSts DMASR[23:16]
#   frm        1 = a frame completed since last sample (FrmCnt_Irq relatch)
#   pix        checksum of 8 words spread over the capture frame; changes = live

DEVMEM=/sbin/devmem
GPIO=0x41200000
VDMA=0x43020000
SLOT=                      # capture frame address: read from S2MM frame store 0
FRAME_BYTES=$((1280*720*4))

rd() { $DEVMEM $1 32; }

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
	frm=$(( ($sr >> 12) & 1 ))
	# clear FrmCnt_Irq so the next sample shows only new frames
	[ $frm -eq 1 ] && $DEVMEM $((VDMA + 0x34)) 32 0x00001000
	printf "%s  pL=%d aL=%d ov=%d un=%d  DMACR=%s DMASR=%s fc=%3d frm=%d pix=%s %s\n" \
		"$(date +%T)" \
		$(( (g >> 10) & 1 )) $(( (g >> 11) & 1 )) \
		$(( (g >> 12) & 1 )) $(( (g >> 13) & 1 )) \
		$cr $sr $(( ($sr >> 16) & 0xff )) $frm "$(pixsum)" \
		"$(decode_sr $sr)"
}

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
