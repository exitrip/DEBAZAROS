# original_flash/ - the board's original NAND (miner firmware)

Dump of the soldered NAND of the bench board (2026-10-26), read on the
board with the new image (the NAND is `/dev/mtd0` since the dtsi enables it).
Chip: Winbond W29N01HV, 128 MiB SLC, 128 KiB erase blocks, 2048 + 64 byte
pages. Read only; nothing was written to the chip.

Binaries are NOT in git (the dump is larger than the GitHub 100 MB file
limit, and the extracted files are the vendor's software):

| File | What |
| --- | --- |
| `nand_data.bin` | 128 MiB, ECC-corrected data (`nanddump --bb=dumpbad`), offsets = chip offsets. md5 `cd4f601587d8d9189e2da99c9bf3046e` (read twice, same) |
| `nand_raw_oob.bin` | 132 MiB, raw pages without ECC correction, each followed by its 64 OOB bytes (`--noecc --oob`). md5 `a56ef12eaa64c2990a672f8540b84ffb` |
| `parts/`, `extracted/` | made by `split_flash.py` (tracked) from `nand_data.bin` |

Make them again: `python3 split_flash.py nand_data.bin` (needs `pip install
fdt jefferson` and `cpio`). To read another board: on that board,
`sudo nanddump --bb=dumpbad -f nand_data.bin /dev/mtd0` (to the SD card,
not to /tmp: /tmp is RAM).

## Layout (from the kernel device tree at 0x800000)

| Partition | Offset | Size | Content |
| --- | --- | --- | --- |
| nand-fsbl-uboot | 0x0000000 | 3 MB | Zynq boot image: FSBL (98 KB) + bitstream (2.08 MB) + U-Boot 2015.07 (510 KB, 2017-06-28, load 0x04000000). ONE image, no golden/multiboot copy |
| nand-linux | 0x0300000 | 5 MB | uImage, Linux 4.6.0-xilinx (zImage) |
| nand-device-tree | 0x0800000 | 128 KB | kernel DTB (has this partition table; memory 256 MB) |
| nand-rootfs | 0x0820000 | 10 MB | uImage ramdisk, gzip cpio, 440 files (the system that boots) |
| nand-jffs2 | 0x1220000 | 16 MB | JFFS2, writable config + app banks (below) |
| nand-bitstream | 0x2220000 | 8 MB | runtime bitstream `.bit`: design `top_ctrl`, 7z010clg400, Vivado 2016.4, built 2017-10-17 |
| nand-allrootfs | 0x2a20000 | 64 MB | JFFS2, full root file system, 729 files |
| nand-release | 0x6a20000 | 19.9 MB | erased (unused update area) |
| nand-reserve | 0x7e00000 | 2 MB | bad-block table (the 4 "bad" blocks at the end) |

U-Boot's own DTB (inside U-Boot) is the Xilinx ZedBoard reference ("Zynq
Zed Development Board", 512 MB, QSPI partitions; this board has no QSPI).

## Findings

- Vendor: Ebang "Ebit" miner control card (SNMP communities `ebiteRead` /
  `ebiteWrite`; miner program `dwang_btc_miner`, tar owner `wuyuhuan`).
- **Factory MAC** in `nand-jffs2/system/eth0_mac.conf`: `8C:C7:D0:0F:4F:C1`
  (this board). Each board probably has its own: a first-boot service can
  read it from /dev/mtd0 and write the uEnv.txt MAC (ROADMAP.md section 10).
- Old network setup `eth0_ip.conf`: 192.168.1.100/24, gateway 192.168.1.1.
- Update scheme = A/B banks at application level, not a second boot image:
  `system/bank.conf` selects `work0/` or `work1/`; `system/appstartup`
  copies that bank's `btc_upgrade.tar.gz` to /tmp, `system/startscrip`
  unpacks it (miner, net-snmp libs, snmpd, `HKDW.tar.gz`) and starts it;
  after 30 s without the miner process it tries the other bank. On this
  board both banks hold the same package (md5 a35b2c70..., 2017-05-29).
- Other config files: temperature thresholds, `chan.conf`, `devconfig` +
  `devconfig.bak`, `snmp.save`, `logfile.txt`.
