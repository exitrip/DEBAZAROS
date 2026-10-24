# Device tree fix: reserve 128 MB for the video frames

Status: **`system-96M.dtb` INSTALLED and VERIFIED (2026-10-24)** as /boot/system.dtb
(md5 af849cb8…): iomem hole present, /dev/fb0 registered, 6/6 slots usable.

⚠️ **Do not use `system-128M.dtb`.** It was installed first and booted, but the
kernel REJECTED the region: `/proc/iomem` showed `00000000-0fffffff : System
RAM` (no hole, 242 MB for Linux) and simplefb failed with -12, so `/dev/fb0`
was gone. The node still appeared in /proc/device-tree. Probable cause: a
region up to the top of RAM (0x1000_0000) overlaps the DTB blob that U-Boot
relocates to the top of RAM; kernel 5.15 refuses a `no-map` region that
overlaps an existing reservation (-EBUSY). The 96 MB region
(0x0800_0000-0x0DFF_FFFF) leaves the top 32 MB free. It still holds all 6
slots (to 0x0AF7_6000) and hdmi2's whole map span (to 0x0DEE_C000).

## The problem

The running image on the bench board reserves only **16 MB**
(`reserved-memory reg = <0x08000000 0x01000000>`, checked in
`/proc/device-tree` and `/proc/iomem`). The 128 MB reservation in the repo
`system-user.dtsi` (commit 45a668cb, Jul 2026) was never built into the
image on this board.

So `0x0900_0000`–`0x0FFF_FFFF` is normal Linux RAM, but the video software
writes there:

| Writer | Address | Effect |
| --- | --- | --- |
| capture VDMA (hdmi2 slot 4) | `0x09FA_4000`, 3.7 MB, 60×/s | overwrites Linux RAM all the time |
| hdmi2 "Loop furever" (boot mode) | display 1 slot 2, `0x08FD_2000`–`0x0935_6000` | overwrites 3.4 MB of RAM every 10 s |
| fbfeed default, oscdraw slots 2–5 | slots 2–5 | overwrites RAM |

Seen on 2026-10-19: heap corruption in unrelated programs
(`malloc(): corrupted top size`). This is the probable cause of the
"mysterious full-board hangs".

Done already, without a reboot: the running capture was moved to slot 1
(inside the 16 MB), and debazd, fbfeed and hdmi2 (sw/) now refuse frames
outside the reservation of the running kernel.

## The fix

`system-96M.dtb` = the original DTB (`/sys/firmware/fdt` of 2026-10-19, saved
as `running-20261019-16M.dtb`) with ONE change:

```
-			reg = <0x8000000 0x1000000>;
+			reg = <0x8000000 0x6000000>;
```

Verified: decompile both, diff = that line only. Linux keeps 160 MB of RAM
(today it uses about 30 MB plus cache).

`boot.scr` loads `/system.dtb` from the FAT boot partition when the file
exists, before the DTB inside BOOT.BIN. So no PetaLinux rebuild is needed.

## Install (on the board)

```sh
sudo cp /home/ebaz/system-96M.dtb /boot/system.dtb
sync
sudo reboot        # then JTAG-flash the dev bitstream as usual
```

Check after the boot:

```sh
od -An -tx4 --endian=big /proc/device-tree/reserved-memory/*/reg   # 08000000 06000000
sudo grep "System RAM" /proc/iomem      # 00000000-07ffffff and 0e000000-0fffffff
                                        # (a HOLE at 0x08000000: that is the proof)
ls /dev/fb0                                                         # must exist
/home/ebaz/bin/dzctl /info                                          # last value: 6 usable slots
```

## Rollback

If the board does not boot: put the SD card in a PC and delete `system.dtb`
from the FAT partition. U-Boot then uses the DTB in BOOT.BIN again.
On a running board: `sudo rm /boot/system.dtb && sudo reboot`.

## Later

When PetaLinux is rebuilt (ROADMAP task 4): the repo dtsi has the 128 MB
reservation, which fails in the same way. Change it to 96 MB
(`<0x08000000 0x06000000>`), or move U-Boot's `fdt_high` below 0x0800_0000. Then delete `/boot/system.dtb`, or keep this file in step
with the new image.
