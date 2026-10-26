#!/usr/bin/env python3
"""split_flash.py - break the dump of the board's original NAND (Ebang "Ebit"
miner control card, Winbond W29N01HV 128 MiB) into its parts.

    python3 split_flash.py [nand_data.bin]      (output: parts/ and extracted/)

Needs: Python 3; for the .dts files and the JFFS2 file systems the packages
`fdt` and `jefferson` (pip install fdt jefferson); `cpio` for the ramdisk.
The layout comes from the kernel device tree inside the dump (0x800000).
"""
import gzip, os, struct, subprocess, sys

SRC = sys.argv[1] if len(sys.argv) > 1 else 'nand_data.bin'
d = open(SRC, 'rb').read()
HERE = os.path.dirname(os.path.abspath(SRC))
PARTS = os.path.join(HERE, 'parts')
EXTR = os.path.join(HERE, 'extracted')
os.makedirs(PARTS, exist_ok=True)
os.makedirs(EXTR, exist_ok=True)
be32 = lambda b, o: struct.unpack('>I', b[o:o + 4])[0]
le32 = lambda b, o: struct.unpack('<I', b[o:o + 4])[0]

def save(dirname, name, data):
    p = os.path.join(dirname, name)
    open(p, 'wb').write(data)
    print('  %-44s %10d bytes' % (os.path.relpath(p, HERE), len(data)))
    return p

# 1. partitions (kernel DTB at 0x800000, flash@e1000000)
TABLE = [('nand-fsbl-uboot', 0x0000000, 0x0300000), ('nand-linux', 0x0300000, 0x0500000),
         ('nand-device-tree', 0x0800000, 0x0020000), ('nand-rootfs', 0x0820000, 0x0a00000),
         ('nand-jffs2', 0x1220000, 0x1000000), ('nand-bitstream', 0x2220000, 0x0800000),
         ('nand-allrootfs', 0x2a20000, 0x4000000), ('nand-release', 0x6a20000, 0x13e0000),
         ('nand-reserve', 0x7e00000, 0x0200000)]
print('== partitions')
part = {}
for name, off, size in TABLE:
    part[name] = d[off:off + size]
    save(PARTS, '%02d_%s.bin' % (len(part) - 1, name), part[name])

# 2. Zynq boot image: partition header table at 0xc80, 64-byte entries, words
print('== Zynq boot image (nand-fsbl-uboot)')
names = {1: 'fsbl.bin', 2: 'bitstream_boot.bin'}
for i in range(8):
    e = 0xc80 + i * 64
    w = struct.unpack('<16I', d[e:e + 64])
    if w[0] == 0 and w[1] == 0:
        break
    length, data_off, attr = w[1] * 4, w[5] * 4, w[6]
    dest = (attr >> 4) & 7
    name = 'u-boot.bin' if dest == 1 and i > 0 else names.get(dest, 'partition%d.bin' % i)
    save(PARTS, 'boot_' + name, d[data_off:data_off + length])

# 3. uImages: kernel and ramdisk (64-byte header, big endian)
def uimage(blob):
    size, comp = be32(blob, 12), blob[31]
    return blob[:64], blob[64:64 + size], comp, blob[32:64].split(b'\0')[0].decode('latin1')
print('== kernel and ramdisk')
hdr, kern, comp, kname = uimage(part['nand-linux'])
save(PARTS, 'kernel_%s.zImage' % kname, kern)
hdr, rd, comp, _ = uimage(part['nand-rootfs'])
rdimg = gzip.decompress(rd) if comp == 1 else rd
p = save(PARTS, 'ramdisk.img', rdimg)
if rdimg[:6] in (b'070701', b'070702'):            # cpio (initramfs)
    out = os.path.join(EXTR, 'ramdisk')
    os.makedirs(out, exist_ok=True)
    subprocess.run(['cpio', '-idm', '--quiet', '--no-absolute-filenames', '-D', out], input=rdimg, check=False)
    print('  extracted/ramdisk/ (cpio)')
elif le32(rdimg, 0x438) & 0xffff == 0xEF53:           # ext2/3/4
    print('  ramdisk.img is an ext2/3/4 image: read it with debugfs or mount -o ro,loop')

# 4. device trees (.dtb + .dts)
print('== device trees')
dtbs = {'kernel.dtb': 0x800000}
i = d.find(b'\xd0\x0d\xfe\xed', 0x200000, 0x300000)  # U-Boot's own DTB inside the U-Boot partition
while i >= 0 and be32(d, i + 20) not in (16, 17):    # skip false matches in code: check the DTB version
    i = d.find(b'\xd0\x0d\xfe\xed', i + 4, 0x300000)
if i >= 0:
    dtbs['u-boot.dtb'] = i
for name, off in dtbs.items():
    blob = d[off:off + be32(d, off + 4)]
    save(PARTS, name, blob)
    try:
        import fdt
        open(os.path.join(PARTS, name[:-4] + '.dts'), 'w').write(fdt.parse_dtb(blob).to_dts())
        print('  %-44s (text)' % ('parts/' + name[:-4] + '.dts'))
    except Exception as ex:
        print('  (no .dts: %s)' % ex)

# 5. runtime bitstream: Xilinx .bit header (fields a..e), keep it as a .bit file
print('== nand-bitstream')
b = part['nand-bitstream']
o, info = 13, {}                                     # skip the 13-byte preamble
while o < 200:
    key = chr(b[o])
    if key == 'e':
        length = be32(b, o + 1)
        save(PARTS, 'bitstream_runtime.bit', b[:o + 5 + length])
        break
    n = struct.unpack('>H', b[o + 1:o + 3])[0]
    info[key] = b[o + 3:o + 3 + n].rstrip(b'\0').decode('latin1')
    o += 3 + n
print('  design %s, part %s, built %s %s' % (info.get('a'), info.get('b'), info.get('c'), info.get('d')))

# 6. JFFS2 file systems
print('== JFFS2')
for name in ('nand-jffs2', 'nand-allrootfs'):
    out = os.path.join(EXTR, name)
    src = os.path.join(PARTS, '%02d_%s.bin' % ([t[0] for t in TABLE].index(name), name))
    # jefferson guesses the byte order from the start of the file and gets it
    # wrong when the partition starts with an erased block: start it at the
    # first block with the little-endian JFFS2 magic (85 19).
    blob = open(src, 'rb').read()
    first = next((o for o in range(0, len(blob), 0x20000) if blob[o:o + 2] == b'\x85\x19'), 0)
    trimmed = os.path.join(PARTS, '.%s.from-first-node.bin' % name)
    open(trimmed, 'wb').write(blob[first:])
    r = subprocess.run(['jefferson', '-f', '-d', out, trimmed], capture_output=True, text=True)
    os.remove(trimmed)
    files = sum(len(f) for _, _, f in os.walk(out)) if os.path.isdir(out) else 0
    print('  extracted/%-34s %d files%s' % (name + '/', files, '' if r.returncode == 0 else ' (jefferson: %s)' % r.stderr.strip()[-200:]))
