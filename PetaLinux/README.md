# PetaLinux project (DEBAZAROS)

PetaLinux 2022.2 project for the DEBAZAROS units: FSBL, U-Boot, kernel,
device tree and root file system. Only `project-spec/` and the small files
are tracked; `build/` (about 80 GB) and `images/` exist only on the build
machine (Ubuntu 22.04; PetaLinux 2022.2 does not work well on 24.04).

## Scripts (`scripts/`)

| Script | What it does |
| --- | --- |
| `build.sh` | silentconfig, build, BOOT.BIN (with the bitstream), WIC + `.wic.xz` |
| `cache-backup.sh` | copy downloads + sstate to `$PLNX_CACHE` (default `~/petalinux-2022.2-cache`) |
| `fetch-all.sh` | download the source of every recipe in the image (network on) |
| `offline-test.sh [--no-sstate]` | build a copy with only the backup and no network, compare with `images/linux` |
| `bitbake-env.sh` | source it for plain `bitbake` with PetaLinux's environment |

Settings in `scripts/common.sh` (`PLNX_SETTINGS`, `PLNX_PROJECT`,
`PLNX_CACHE`). The steps the scripts run are below.

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

## Our software in the image (recipe `debaz-sw`, 2026-11-01)

`project-spec/meta-user/recipes-apps/debaz-sw/debaz-sw.bb` builds the repo's
`sw/` with the Yocto cross compiler (`make` + `make image-install`) and
installs:

| Path | What |
| --- | --- |
| `/usr/bin` | debazd, dzctl, dzweb, fbfeed, dzmosh, hdmi2.elf, vsync_probe, pcmplay, the board scripts (dzstart.sh, plreload.sh, dzsetup.sh, capstat.sh, ...) |
| `/usr/share/debaz/www` | the web app |
| `/etc/debaz/dzstart.conf` | bring-up settings (BITSTREAM empty = BOOT.BIN's) |
| `/lib/systemd/system/debaz.service` | runs `dzstart.sh` at boot (after debaz-firstboot) |
| `/lib/firmware` | the bitstreams in `DEBAZ_BITSTREAMS` (current + fallback) from `artifacts/` |

and pulls in ffmpeg, alsa-utils (aplay/arecord, amixer, alsactl),
util-linux-setpriv and the fonts (liberation-fonts, ttf-dejavu sans / mono /
serif). The source is the checked-out repo (like `debaz-firstboot`, via
`FILESEXTRAPATHS`): commit, bring the commit to the build machine, build.
Bitbake hashes every file under `sw/`, so a change rebuilds the package.

Rules:

- **The software and the bitstream in BOOT.BIN belong together**
  (`sw/include/hw_map.h`). When `hw_map.h` changes, import the matching XSA
  (below) and set `DEBAZ_BITSTREAMS` in the recipe.
- A development copy (`make -C sw install`: `/home/ebaz/bin`, `/home/ebaz/www`)
  wins over the image's files on that card (`sw/lib/dz_path.h`); delete it to
  go back.
- Build only the package: `petalinux-build -c debaz-sw`; its files (the work
  folder is cleaned after the build): `rpm2cpio
  build/tmp/deploy/rpm/cortexa9t2hf_neon/debaz-sw-1.0-r0.0.cortexa9t2hf_neon.rpm | cpio -idm`.

First image with the recipe: `debazaros-20261101-sw.wic.xz` (sandbox build
2026-11-01, `_sdly` XSA, 602 packages; on the laptop in
`build/images/`, git-ignored). Checked in the build output: BOOT.BIN's
bitstream = `_sdly.bit`, `debaz.service` enabled, fonts and both bitstreams
in the rootfs; the Yocto-built debazd/dzctl/dzweb/fbfeed/dzmosh ran on the
Oct 28 image. NOT yet booted from a card. First boot of a new card, expected:
debaz-firstboot makes the data + media partitions and the MAC, reboots once;
then `debaz.service` starts hdmi2 (720p60), debazd, the boot setup (mixer,
sync delays) and dzweb. Check: `journalctl -u debaz` ends with "dzstart: OK",
both outputs show the hdmi2 test pattern, `http://<unit>:8080/` works,
`dzctl /files fonts` lists the Liberation and DejaVu fonts.

Bring the recipe to the build machine's clone: commit; on the build machine
stash or reset the old uncommitted edits (CLAUDE.md, PetaLinux section),
ff-merge the bundle, then import the `_sdly` XSA there too
(`petalinux-config --get-hw-description=<repo>/artifacts/ebaz4205_2out1in_20261101_sdly.xsa`
+ the two cleansstate lines below) and `scripts/build.sh`.

Install after image creation (`make -C sw install`) stays the development
loop; the recipe makes every flashed card a working unit without a laptop
(the fleet: one image for all cards).

## Sandbox build (does not touch this project, 2026-11-01)

To test a change of `project-spec` without a commit, and without changing
the build machine's clone: copy the project without `build/` and `images/`,
put the changed files over it, use this project's sstate cache as a mirror:

```sh
SB=~/dz-sandbox/DEBAZAROS            # the repo layout: PetaLinux/, sw/, artifacts/
rsync -a --exclude /build/ --exclude /images/ ~/Documents/projects/DEBAZAROS/PetaLinux/ $SB/PetaLinux/
# + the changed files (rsync from the laptop), then in $SB/PetaLinux:
sed -i "s#^CONFIG_YOCTO_LOCAL_SSTATE_FEEDS_URL=.*#CONFIG_YOCTO_LOCAL_SSTATE_FEEDS_URL=\"$HOME/Documents/projects/DEBAZAROS/PetaLinux/build/sstate-cache\"#" project-spec/configs/config
bash scripts/build.sh
```

The sandbox needs `sw/` and `artifacts/` beside `PetaLinux/` (the recipes
read them through relative paths). The 2026-11-01 run is in
`~/dz-sandbox/` on the build machine (`sandbox-build.sh`, `build.log`).

## New hardware description (XSA)

All gateware variants share one PS7 configuration (ROADMAP.md section 8;
`ps7_init.c` of `_pwm` and `_sdly` are identical), so import an XSA only
when the PS7 setup changes, or to change the default bitstream in BOOT.BIN.
The Oct 28 image was built from `_pwm` (its BOOT.BIN bitstream is older than
the software since build `osc`: such a card needs `dzstart.sh` with
BITSTREAM); the next image from `_sdly`. Use a hardware-tested XSA from `artifacts/`:

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

## Backup and local-only build (tested 2026-10-25)

Upstream download addresses disappear over the years (LuaJIT, 2026-10-25),
and this project also uses AMD's `petalinux.xilinx.com` pre-mirror and
sstate feed. A backup of the caches makes the build independent of them.

1. Backup (after a green build): copy `build/downloads/` without its
   `git2/` bare clones (PetaLinux keeps a `git2_*.tar.gz` mirror tarball
   for every git source) and `build/sstate-cache/`. Script on the build
   machine: `~/plnx-cache-backup.sh` -> `~/petalinux-2022.2-cache/`
   (24 GB). Keep a copy on another disk.
2. Local-only build: in `project-spec/configs/config` set

   ```text
   CONFIG_PRE_MIRROR_URL="file:///<backup>/downloads"
   # CONFIG_YOCTO_NETWORK_SSTATE_FEEDS is not set
   CONFIG_YOCTO_LOCAL_SSTATE_FEEDS_URL="/<backup>/sstate-cache"
   CONFIG_YOCTO_BB_NO_NETWORK=y
   ```

   These paths are per machine, so the tracked config keeps the network
   defaults; use the settings in a local copy, or set them only on the
   build machine.

Test result: a copy of the project with no `build/` built with these
settings in 10 minutes; `system.bit`, `system.dtb` and the rootfs package
list were identical to the networked build. The test used the sstate
cache for most tasks, so it proves the backup for THIS configuration; a
new package still needs one networked build (then back up again).

## Configuration choices (2026-10-25)

- `CONFIG_SUBSYSTEM_FPGA_MANAGER` OFF: BOOT.BIN keeps the default bitstream,
  so the ethernet PHY clock (from the PL) is always there.
- `CONFIG_SUBSYSTEM_REMOVE_PL_DTB` ON: no PL nodes in the device tree; no
  kernel driver touches the VDMAs or the VTC. debazd/hdmi2 use /dev/mem.
- One device tree source:
  `project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`
  (96 MB frame memory, one simplefb, fpga-full region, soldered NAND).
- Kernel fragments in `project-spec/meta-user/recipes-kernel/linux/linux-xlnx/`
  (`user_2026-10-25-debaz.cfg`: exFAT, UBI/UBIFS; `user_2026-10-27-plio.cfg`:
  Cadence I2C/SPI, i2c-dev, spidev for the user I/O lines). Removed
  2026-10-27: `user_2023-05-08-18-39-00.cfg` (Xilinx I2S + Audio Formatter +
  PL sound card + ADAU1761 codec, a 2023 test): the HDMI audio of this design
  is all in the PL (hdmi_tx / hdmi_rx / pl_io I2S), there is no Audio
  Formatter, I2S IP or codec, and with REMOVE_PL_DTB those drivers never probed.
- rootfs: SDR-era packages removed (361 MB); ffmpeg, parted, dosfstools,
  exfat-utils, mtd-utils, rsync, python3 added. ffmpeg needs the
  `commercial` license flag (`meta-user/conf/petalinuxbsp.conf`).

Plan for the full SD card image (partitions, read-only root): ROADMAP.md
section 10. Partitions and the first boot: done (debaz-firstboot); our
software as a recipe + systemd start-up: done (debaz-sw, above).

`dtb/`: the 96 MB DTB that runs on the bench board now (before this image).
