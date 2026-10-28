#!/bin/sh
# debaz-mac.sh - commissioning: give a card its own ethernet MAC and hostname
# (2026-10-28; ROADMAP.md "Fleet", FLEET.md F1). On the board, as root.
#
#   sudo sh debaz-mac.sh                show the MAC now, the uEnv.txt one, the CID one
#   sudo sh debaz-mac.sh -w [MAC] [-r]  write it (default: from the SD card CID); -r reboots
#   debaz-mac.sh --firstboot            (systemd debaz-firstboot.service) nothing if
#                                       uEnv.txt has a MAC, else -w -r: one extra boot
#
# Every board runs the Xilinx default MAC 00:0a:35:00:1e:53 (PetaLinux
# config -> DT local-mac-address), and the Ebang "factory" MAC in the NAND
# (eth0_mac.conf) is the same on every board too (8C:C7:D0:0F:4F:C1 on two
# different boards, 2026-10-28). So the MAC comes from the SD card CID
# (unique per card): md5("debaz:" CID), first octet = locally administered
# unicast (x2:..). The identity belongs to the card, like the rest of the
# per-card setup.
#
# How it is applied: boot.scr imports /boot/uEnv.txt and runs `uenvcmd`;
# `setenv -f` overrides U-Boot's write-once protection of ethaddr; U-Boot's
# fdt fixup then puts it into the DT (mac-address) for the kernel. A reboot
# is needed. The DHCP server then gives the board a new address.
# The hostname becomes debaz-<last 3 MAC bytes> (/etc/hostname, at once).
set -e
UENV=/boot/uEnv.txt
CID=/sys/block/mmcblk0/device/cid

cid_mac() {
	h=$(printf 'debaz:%s' "$(cat $CID)" | md5sum | cut -c1-12)
	b0=$(( (0x$(echo "$h" | cut -c1-2) & 0xFC) | 0x02 ))
	printf '%02x:%s:%s:%s:%s:%s\n' $b0 $(echo "$h" | cut -c3-4) $(echo "$h" | cut -c5-6) \
		$(echo "$h" | cut -c7-8) $(echo "$h" | cut -c9-10) $(echo "$h" | cut -c11-12)
}

uenv_mac() {
	[ -f $UENV ] && sed -n 's/^dz_ethaddr=//p' $UENV
}

valid() {	# unicast, not all zero, xx:xx:xx:xx:xx:xx
	echo "$1" | grep -qiE '^[0-9a-f][02468ace](:[0-9a-f]{2}){5}$' &&
		[ "$1" != "00:00:00:00:00:00" ]
}

write=0 boot=0 mac=
while [ $# -gt 0 ]; do
	case $1 in
	-w) write=1 ;;
	-r) boot=1 ;;
	--firstboot)
		if [ -n "$(uenv_mac)" ]; then exit 0; fi
		echo "debaz-firstboot: no MAC in $UENV: commissioning this card"
		write=1 boot=1 ;;
	-h) sed -n '5,8p' "$0"; exit 0 ;;
	*) mac=$1 ;;
	esac
	shift
done

now=$(cat /sys/class/net/eth0/address)
echo "MAC now:       $now"
echo "uEnv.txt MAC:  $(uenv_mac || true)"
echo "from SD CID:   $(cid_mac)   (CID $(cat $CID))"
echo "hostname:      $(cat /etc/hostname)"
[ $write = 1 ] || exit 0

[ -n "$mac" ] || mac=$(cid_mac)
mac=$(echo "$mac" | tr 'A-F' 'a-f')
valid "$mac" || { echo "not a unicast MAC: $mac"; exit 1; }

# keep other uEnv.txt lines; ours are dz_ethaddr and uenvcmd
tmp=$UENV.new
{ [ -f $UENV ] && grep -v -e '^dz_ethaddr=' -e '^uenvcmd=' $UENV || true
  echo "dz_ethaddr=$mac"
  echo 'uenvcmd=setenv -f ethaddr ${dz_ethaddr}'
} > $tmp
mv $tmp $UENV
sync
host=debaz-$(echo "$mac" | tr -d ':' | cut -c7-12)
echo "$host" > /etc/hostname
hostname "$host"
echo "wrote $UENV (MAC $mac) and hostname $host"
if [ "$now" = "$mac" ]; then
	echo "the MAC is already in use: no reboot needed"
elif [ $boot = 1 ]; then
	echo "rebooting; the board comes back with MAC $mac (new DHCP address)"
	sync
	systemctl reboot --no-block	# --no-block: also from a unit during boot
else
	echo "reboot to apply (the DHCP address will change)"
fi
