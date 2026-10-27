#!/usr/bin/env python3
"""edid_audio.py - make the HDMI_2 capture EDID advertise HDMI audio, in ONE
format: L-PCM, 2 channels, 48 kHz, 16 bit (all media is pre-rendered to it).

    python3 hw/edid_audio.py [IP_dvi2rgb/src/dgl_720p_cea.data]

The file is dvi2rgb's EEPROM init file: 256 lines, one byte per line in
binary. The script changes only the CEA-861 extension (block 1):
  - flags byte: + "basic audio" (bit 6); YCbCr bits stay 0 (RGB only)
  - Audio Data Block: LPCM, 2 ch, 48 kHz, 16 bit
  - HDMI Vendor-Specific Data Block (OUI 00-0C-03, physical address 1.0.0.0):
    without it a source sends DVI (no data islands, no audio)
  - the detailed timing descriptors move up; checksum again.
The base block and the video data block do not change. Running it twice
changes nothing. Then: hw/repackage_ip.tcl IP_dvi2rgb, rebuild.
"""
import sys

path = sys.argv[1] if len(sys.argv) > 1 else 'IP_dvi2rgb/src/dgl_720p_cea.data'
lines = open(path).read().split()
d = [int(x, 2) for x in lines]
assert len(d) == 256, 'want 256 bytes'
assert sum(d[0:128]) % 256 == 0, 'base block checksum'
e = d[128:256]
assert e[0] == 0x02 and e[1] == 3, 'want a CEA-861 extension, revision 3'

# collect the data blocks and the DTDs
blocks, i = [], 4
while i < e[2]:
    tag, ln = e[i] >> 5, e[i] & 31
    blocks.append((tag, e[i + 1:i + 1 + ln]))
    i += 1 + ln
dtds, i = [], e[2]
while i + 18 <= 127 and (e[i] or e[i + 1]):
    dtds.append(e[i:i + 18])
    i += 18

ADB = (1, [0x09, 0x04, 0x01])            # LPCM, 2 ch; 48 kHz; 16 bit
VSDB = (3, [0x03, 0x0C, 0x00, 0x10, 0x00])
blocks = [b for b in blocks if b[0] not in (1, 3)]
blocks.insert(1, ADB)                    # after the video data block
blocks.insert(2, VSDB)

out = [0x02, 0x03, 0, e[3] | 0x40]
for tag, body in blocks:
    out += [(tag << 5) | len(body)] + list(body)
out[2] = len(out)
for t in dtds:
    out += t
assert len(out) <= 127, 'extension too long'
out += [0] * (127 - len(out))
out.append((-sum(out)) % 256)
d[128:256] = out

with open(path, 'w') as f:
    f.write('\n'.join(format(b, '08b') for b in d) + '\n')
print('%s: %d data blocks, %d DTDs, extension checksum %02x' % (path, len(blocks), len(dtds), out[127]))
