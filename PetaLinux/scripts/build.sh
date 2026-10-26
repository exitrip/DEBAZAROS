#!/bin/bash
# build.sh - full build: config sync -> petalinux-build -> BOOT.BIN -> WIC.
#   scripts/build.sh            (log: build-<date>.log beside the project)
# After it: commit the files that silentconfig rewrote (git status
# project-spec/configs .petalinux), see README.md.
set -u
source "$(dirname "$0")/common.sh"
cd "$PLNX_PROJECT" || exit 1
source "$PLNX_SETTINGS" >/dev/null
echo "== start $(date)"
petalinux-config --silentconfig || { echo "== FAILED silentconfig"; exit 1; }
petalinux-config -c rootfs --silentconfig || { echo "== FAILED rootfs silentconfig"; exit 1; }
petalinux-build || { echo "== FAILED build"; exit 2; }
petalinux-package --boot --force --fsbl images/linux/zynq_fsbl.elf \
    --fpga images/linux/system.bit --u-boot || { echo "== FAILED BOOT.BIN"; exit 3; }
petalinux-package --wic --bootfiles "BOOT.BIN boot.scr uImage system.dtb" \
    || { echo "== FAILED wic"; exit 4; }
xz -T0 -3 -k -f images/linux/petalinux-sdimage.wic
ls -la images/linux/BOOT.BIN images/linux/system.dtb images/linux/uImage \
    images/linux/rootfs.ext4 images/linux/petalinux-sdimage.wic.xz
echo "== rootfs packages: $(wc -l < images/linux/rootfs.manifest)"
echo "== DONE $(date)"
