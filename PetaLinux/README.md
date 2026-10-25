# PetaLinux project (DEBAZAROS)

PetaLinux 2022.2 project for the DEBAZAROS units: FSBL, U-Boot, kernel,
device tree and root file system. Only `project-spec/` and the small files
are tracked; `build/` (about 80 GB) and `images/` exist only on the build
machine (Ubuntu 22.04; PetaLinux 2022.2 does not work well on 24.04).

## Build

```sh
cd PetaLinux
source ~/petalinux/2022.2/settings.sh
petalinux-config --silentconfig
petalinux-config -c rootfs --silentconfig
petalinux-build
petalinux-package --boot --force --fsbl images/linux/zynq_fsbl.elf \
    --fpga images/linux/system.bit --u-boot
```

Output in `images/linux/`: `BOOT.BIN` (FSBL + default bitstream + U-Boot),
`uImage`, `system.dtb`, `boot.scr`, `rootfs.ext4` / `rootfs.tar.gz`.

`silentconfig` rewrites `project-spec/configs/*` (sorts, removes stale
entries, may switch dependencies on). Commit the rewritten files, or the
next `git pull` on the build machine refuses to overwrite them.

## New hardware description (XSA)

All gateware variants share one PS7 configuration (ROADMAP.md section 8),
so import an XSA only when the PS7 setup changes, or to change the default
bitstream in BOOT.BIN. Use a hardware-tested XSA from `artifacts/`:

```sh
petalinux-config --get-hw-description=<repo>/artifacts/<variant>_<date>.xsa --silentconfig
# REQUIRED after every import: the FSBL and device-tree recipes keep an
# xsct workspace with the OLD hardware; without this the FSBL step fails
# with "Failed to generate bsp for application zynq_fsbl".
petalinux-build -c fsbl-firmware -x cleansstate
petalinux-build -c device-tree -x cleansstate
petalinux-build
```

No new PetaLinux project is necessary for a new XSA.

## Configuration choices (2026-10-25)

- `CONFIG_SUBSYSTEM_FPGA_MANAGER` OFF: BOOT.BIN keeps the default bitstream,
  so the ethernet PHY clock (from the PL) is always there.
- `CONFIG_SUBSYSTEM_REMOVE_PL_DTB` ON: no PL nodes in the device tree; no
  kernel driver touches the VDMAs or the VTC. debazd/hdmi2 use /dev/mem.
- One device tree source:
  `project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`
  (96 MB frame memory, one simplefb, fpga-full region, soldered NAND).
- Kernel fragments in `project-spec/meta-user/recipes-kernel/linux/linux-xlnx/`
  (`user_2026-10-25-debaz.cfg`: exFAT, UBI/UBIFS).
- rootfs: SDR-era packages removed (361 MB); ffmpeg, parted, dosfstools,
  exfat-utils, mtd-utils, rsync, python3 added. ffmpeg needs the
  `commercial` license flag (`meta-user/conf/petalinuxbsp.conf`).

Plan for the full SD card image (partitions, our software as a recipe,
systemd start-up, read-only root): ROADMAP.md section 10.

`dtb/`: the 96 MB DTB that runs on the bench board now (before this image).
