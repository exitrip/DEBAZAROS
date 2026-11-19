#!/bin/sh
# pkgpush.sh - put Yocto packages from the build machine onto a RUNNING unit,
# without a new image (2026-11-20). The unit has no package manager: the
# packages' rpm files are unpacked on the build machine (rpm2cpio | cpio) and
# the files go straight into the unit's / over ssh (sudo tar), then ldconfig.
# For trying a package (fluidsynth, a soundfont, a tool) before an image has it.
#
#   sh sw/tools/pkgpush.sh [-b build] [-d deploy-dir] [-t user@unit] [-n] pkg...
#     pkg   package names as in the deploy dir (fluidsynth fluidsynth-bin
#           libglib-2.0-0 debaz-soundfonts ...): the newest <pkg>-<version>.rpm
#     -n    list what would be copied, change nothing on the unit
#   Build them first on the build machine, in the project or the sandbox:
#     petalinux-build -c fluidsynth ; petalinux-build -c debaz-soundfonts
#
# Undo: the file list of each push is kept on the unit in
# /var/lib/debaz-pkgpush/<pkg>.files (delete those files by hand).
# ⚠️ Shared libraries already in the image are NOT replaced by a pkg you do
# not name; name only packages the image lacks (pkgpush prints the files).
set -eu
BUILD=${PKGPUSH_BUILD:-aescape@192.168.1.239}
DEPLOY=${PKGPUSH_DEPLOY:-dz-sandbox/DEBAZAROS/PetaLinux/build/tmp/deploy/rpm}
TARGET=${PKGPUSH_TARGET:-ebaz@10.42.0.236}
DRY=0
while getopts b:d:t:n o; do
	case $o in
	b) BUILD=$OPTARG ;; d) DEPLOY=$OPTARG ;; t) TARGET=$OPTARG ;; n) DRY=1 ;;
	*) sed -n '2,20p' "$0"; exit 2 ;;
	esac
done
shift $((OPTIND - 1))
[ $# -gt 0 ] || { sed -n '2,20p' "$0"; exit 2; }
BSSH="ssh -o IdentitiesOnly=yes -i $HOME/.ssh/id_ed25519 $BUILD"
case "$TARGET" in *10.42.0.*) TSSH="sshpass -p '' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $TARGET" ;;
	*) TSSH="ssh $TARGET" ;; esac

for p in "$@"; do
	# the newest rpm named exactly <pkg>-<version>-<release>.<arch>.rpm
	tar=$($BSSH "set -e; cd $DEPLOY; f=\$(ls -t */$p-[0-9]*.rpm 2>/dev/null | head -1); [ -n \"\$f\" ] || { echo NONE; exit 0; }; echo \$f") || exit 1
	[ "$tar" != NONE ] || { echo "pkgpush: $p: no rpm in $BUILD:$DEPLOY (build it first)" >&2; exit 1; }
	echo "== $p ($tar)"
	$BSSH "cd $DEPLOY && rpm2cpio $tar | cpio -t --quiet" | sed 's#^\./#/#; s#^#   #'
	[ $DRY = 1 ] && continue
	# the top-level entries only (never "." = the unit's /), and existing
	# folders keep their owner and mode (--no-overwrite-dir)
	$BSSH "set -e; d=\$(mktemp -d); cd \$d; rpm2cpio ~/$DEPLOY/$tar | cpio -idm --quiet; tar czf - --owner=0 --group=0 \$(ls -A); cd /; rm -rf \$d" |
		eval "$TSSH" "'sudo tar -C / --no-same-owner --no-overwrite-dir -xzf - && sudo mkdir -p /var/lib/debaz-pkgpush'"
	$BSSH "cd $DEPLOY && rpm2cpio $tar | cpio -t --quiet" | sed 's#^\./#/#' |
		eval "$TSSH" "'sudo tee /var/lib/debaz-pkgpush/$p.files > /dev/null'"
done
[ $DRY = 1 ] || eval "$TSSH" "'sudo ldconfig'"
echo "pkgpush: done"
