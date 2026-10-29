#!/bin/sh
# debaz-firstboot.sh - per-card setup at boot (2026-10-28; ROADMAP.md
# section 10). Run by debaz-firstboot.service at every boot, as root; every
# step first checks whether it is already done, so later boots cost ~0.1 s.
#
#   1. Partitions in the free space after the root (only with >= 2 GiB free;
#      1 MiB aligned):  p3 DEBAZDATA  ext4, 256 MB  -> /data
#                       p4 DEBAZMEDIA exFAT, rest   -> /media/debaz
#      (sfdisk --append + partx -a: no reboot)
#   2. /etc/fstab lines by label, nofail (a missing partition never stops
#      the boot); exFAT with uid/gid of the media user, so debazd (root) and
#      dzweb (ebaz) can both write
#   3. Media folders img/ movies/ audio/ in /media/debaz; files in the old
#      folders /home/ebaz/{img,movies,audio} move there and the old paths
#      become symlinks. Without the partition (no free space, e.g. a card
#      whose root was grown by hand) /media/debaz is a folder on the root.
#   4. The MAC: debaz-mac.sh --firstboot (reboots once if it writes one)
#
# Overrides for tests (e.g. a loop device): DZ_DISK (/dev/mmcblk0), DZ_PART
# (partition name prefix, default ${DZ_DISK}p), DZ_MEDIA, DZ_DATA, DZ_FSTAB,
# DZ_HOME (/home/ebaz), DZ_USER (ebaz), DZ_NOMAC=1 (skip step 4),
# DZ_NOMOUNT=1 (make and format partitions, but no fstab and no mounts).
set -u
DISK=${DZ_DISK:-/dev/mmcblk0}
PART=${DZ_PART:-${DISK}p}
MEDIA=${DZ_MEDIA:-/media/debaz}
DATA=${DZ_DATA:-/data}
FSTAB=${DZ_FSTAB:-/etc/fstab}
HOMED=${DZ_HOME:-/home/ebaz}
USR=${DZ_USER:-ebaz}
DATA_MB=256
MIN_FREE=$((2 * 1024 * 1024 * 2))	# sectors: 2 GiB

PATH=/usr/sbin:/usr/bin:/sbin:/bin
log() { echo "debaz-firstboot: $*"; }
uid=$(id -u "$USR" 2>/dev/null || echo 0)
gid=$(id -g "$USR" 2>/dev/null || echo 0)

# ---- 1. partitions ---------------------------------------------------------------
part_n() {	# number of partitions in the table
	sfdisk -d "$DISK" 2>/dev/null | grep -c "^$DISK"
}
make_parts() {
	n=$(part_n)
	if [ "$n" -ge 3 ]; then
		return 0			# done before (or someone else's layout)
	fi
	if [ "$n" -ne 2 ]; then
		log "unexpected partition table ($n partitions): no new partitions"
		return 0
	fi
	# end of p2, from the table: start + size (sectors)
	set -- $(sfdisk -d "$DISK" | sed -n "s|^${PART}2 *: *start= *\([0-9]*\), *size= *\([0-9]*\).*|\1 \2|p")
	[ $# -eq 2 ] || { log "cannot read partition 2"; return 0; }
	end2=$(($1 + $2))
	total=$(blockdev --getsz "$DISK")
	free=$((total - end2))
	if [ "$free" -lt "$MIN_FREE" ]; then
		log "$((free / 2048)) MiB free after the root: media stays on the root ($MEDIA)"
		return 0
	fi
	s3=$(( (end2 + 2047) / 2048 * 2048 ))
	z3=$((DATA_MB * 2048))
	s4=$(( (s3 + z3 + 2047) / 2048 * 2048 ))
	log "new partitions: data ${DATA_MB} MiB at $s3, media $(( (total - s4) / 2048 )) MiB at $s4"
	printf 'start=%s, size=%s, type=83\nstart=%s, type=7\n' "$s3" "$z3" "$s4" |
		sfdisk --append --no-reread "$DISK" > /dev/null 2>&1
	partx -a -n 3:4 "$DISK" 2>/dev/null || partx -u "$DISK"
	sleep 1
	[ -b "${PART}3" ] && [ -b "${PART}4" ] || { log "kernel does not see the new partitions"; return 1; }
	mkfs.ext4 -q -F -L DEBAZDATA "${PART}3" || { log "mkfs.ext4 failed"; return 1; }
	mkfs.exfat -n DEBAZMEDIA "${PART}4" > /dev/null || { log "mkfs.exfat failed"; return 1; }
	log "formatted ${PART}3 (DEBAZDATA, ext4) and ${PART}4 (DEBAZMEDIA, exFAT)"
}

# ---- 2. fstab + mounts -------------------------------------------------------------
add_fstab() {	# label line
	grep -q "^LABEL=$1 " "$FSTAB" 2>/dev/null && return 0
	echo "$2" >> "$FSTAB"
	log "fstab: $2"
}
mounts() {
	[ "${DZ_NOMOUNT:-0}" = 1 ] && return 0
	if blkid -L DEBAZDATA > /dev/null 2>&1; then
		add_fstab DEBAZDATA "LABEL=DEBAZDATA $DATA ext4 defaults,nofail,x-systemd.device-timeout=10 0 2"
		mkdir -p "$DATA"
		mountpoint -q "$DATA" || mount "$DATA" || log "mount $DATA failed"
	fi
	if blkid -L DEBAZMEDIA > /dev/null 2>&1; then
		add_fstab DEBAZMEDIA "LABEL=DEBAZMEDIA $MEDIA exfat uid=$uid,gid=$gid,fmask=0133,dmask=0022,nofail,x-systemd.device-timeout=10 0 0"
		mkdir -p "$MEDIA"
		mountpoint -q "$MEDIA" || mount "$MEDIA" || log "mount $MEDIA failed"
	fi
}

# ---- 3. media folders --------------------------------------------------------------
folders() {
	mkdir -p "$MEDIA"
	for k in img movies audio; do
		mkdir -p "$MEDIA/$k"
		mountpoint -q "$MEDIA" || chown "$uid:$gid" "$MEDIA" "$MEDIA/$k" 2>/dev/null
		old=$HOMED/$k
		if [ -L "$old" ]; then
			continue			# done before
		fi
		if [ -d "$old" ]; then
			n=$(find "$old" -mindepth 1 -maxdepth 1 | wc -l)
			if [ "$n" -gt 0 ]; then
				log "moving $n file(s) from $old to $MEDIA/$k"
				# mv: a rename on the same file system, else copy + delete
				find "$old" -mindepth 1 -maxdepth 1 -exec mv -f {} "$MEDIA/$k/" \;
			fi
			rmdir "$old" 2>/dev/null || { log "$old not empty: left as it is"; continue; }
		fi
		ln -s "$MEDIA/$k" "$old"
		chown -h "$uid:$gid" "$old" 2>/dev/null
	done
}

make_parts
mounts
folders
if [ "${DZ_NOMAC:-0}" != 1 ] && [ -x /usr/sbin/debaz-mac.sh ]; then
	/usr/sbin/debaz-mac.sh --firstboot
fi
exit 0
