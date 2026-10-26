#!/bin/bash
# offline-test.sh [--no-sstate] - build a COPY of the project (no build/,
# no images/) with only $PLNX_CACHE as source and the network off, then
# compare with this project's images/linux. --no-sstate = compile
# everything (hours): proves the backed-up sources are complete.
set -u
source "$(dirname "$0")/common.sh"
T=${OFFLINE_DIR:-$HOME/plnx-offline-test}
rm -rf "$T"; mkdir -p "$T"
rsync -a --exclude "/build/" --exclude "/images/" --exclude "/.Xil/" \
    --exclude ".vscode*" "$PLNX_PROJECT/" "$T/PetaLinux/"
C=$T/PetaLinux/project-spec/configs/config
SS=$PLNX_CACHE/sstate-cache; [ "${1:-}" = --no-sstate ] && SS=""
sed -i "s#^CONFIG_PRE_MIRROR_URL=.*#CONFIG_PRE_MIRROR_URL=\"file://$PLNX_CACHE/downloads\"#;
        s#^CONFIG_YOCTO_NETWORK_SSTATE_FEEDS=y#\# CONFIG_YOCTO_NETWORK_SSTATE_FEEDS is not set#;
        s#^CONFIG_YOCTO_LOCAL_SSTATE_FEEDS_URL=.*#CONFIG_YOCTO_LOCAL_SSTATE_FEEDS_URL=\"$SS\"#;
        s#^\# CONFIG_YOCTO_BB_NO_NETWORK is not set#CONFIG_YOCTO_BB_NO_NETWORK=y#" "$C"
cd "$T/PetaLinux" && source "$PLNX_SETTINGS" >/dev/null
petalinux-config --silentconfig && petalinux-config -c rootfs --silentconfig \
    && petalinux-build || { echo "== FAILED"; grep -h "Fetcher failure\|^ERROR" build/build.log | sort -u | head -20; exit 1; }
R=$PLNX_PROJECT/images/linux
for f in system.bit system.dtb; do cmp images/linux/$f "$R/$f" && echo "$f identical"; done
diff <(cut -d" " -f1,3 images/linux/rootfs.manifest) <(cut -d" " -f1,3 "$R/rootfs.manifest") \
    && echo "rootfs manifest identical"
echo "== DONE $(date)"
