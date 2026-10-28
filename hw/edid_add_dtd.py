#!/usr/bin/env python3
"""edid_add_dtd.py - set the detailed timing descriptors (DTDs) of the
CEA-861 extension of the HDMI_2 capture EDID (dvi2rgb's EEPROM init file: 256
lines, one byte per line in binary). Runs after edid_audio.py. The extension
gets exactly the MODES below (the old extension DTDs are removed; 720p60 and
1080p30 stay in the base block); the extension checksum is made again.

    python3 hw/edid_add_dtd.py [IP_dvi2rgb/src/dgl_720p_cea.data]
    then: vivado -mode batch -source hw/repackage_ip.tcl -tclargs IP_dvi2rgb

The modes (2026-10-28): inputs whose quarters are standard output modes, for
the debazd crops (/disp/<d>/crop). dvi2rgb (kClkRange = 2) takes 60-120 MHz.
  1280x1024@60: VESA DMT, 108.00 MHz
  1600x1200@30: CVT reduced blanking (H total 1760, V total 1217), 64.25 MHz;
                quarter = 800x600 (output 800x600@60). Before: VESA 1600x1200@60
                blanking at half the clock (81.00 MHz, H total 2160): dvi2rgb
                locked, but hdmi_rx found no frames (2026-10-28).
  1600x1200@25: VESA 1600x1200@60 blanking, 67.50 MHz (test: same shape as
                the 81 MHz timing at another clock)
  1280x960@60:  VESA DMT, 108.00 MHz; quarter = 640x480 (output 640x480@60)
"""
import sys

# (name, pixel clock MHz, h active, front porch, sync, back porch,
#  v active, front porch, sync, back porch, hsync +, vsync +)
MODES = [
    ('1280x1024@60', 108.00, 1280, 48, 112, 248, 1024, 1, 3, 38, True, True),
    ('1600x1200@30', 64.25, 1600, 48, 32, 80, 1200, 3, 4, 10, True, False),
    ('1600x1200@25', 67.50, 1600, 64, 192, 304, 1200, 1, 3, 46, True, True),
    ('1280x960@60', 108.00, 1280, 96, 112, 312, 960, 1, 3, 36, True, True),
]


def dtd(m):
    _, mhz, ha, hfp, hs, hbp, va, vfp, vs, vbp, hp, vp = m
    pc = round(mhz * 100)                       # 10 kHz units
    hb, vb = hfp + hs + hbp, vfp + vs + vbp
    b = [pc & 255, pc >> 8,
         ha & 255, hb & 255, ((ha >> 8) << 4) | (hb >> 8),
         va & 255, vb & 255, ((va >> 8) << 4) | (vb >> 8),
         hfp & 255, hs & 255, ((vfp & 15) << 4) | (vs & 15),
         ((hfp >> 8) << 6) | ((hs >> 8) << 4) | ((vfp >> 4) << 2) | (vs >> 4),
         0, 0, 0,                               # image size: unknown
         0, 0,                                  # no border
         0x18 | (0x04 if vp else 0) | (0x02 if hp else 0)]   # digital separate sync
    return b


path = sys.argv[1] if len(sys.argv) > 1 else 'IP_dvi2rgb/src/dgl_720p_cea.data'
d = [int(x, 2) for x in open(path).read().split()]
assert len(d) == 256 and sum(d[0:128]) % 256 == 0, 'want a valid 256-byte EDID'
e = d[128:256]
assert e[0] == 0x02 and e[1] == 3, 'want a CEA-861 extension, revision 3'

dtds = [dtd(m) for m in MODES]

out = e[:e[2]]
for t in dtds:
    out += t
assert len(out) <= 127, 'extension too long'
out += [0] * (127 - len(out))
out.append((-sum(out)) % 256)
d[128:256] = out
with open(path, 'w') as f:
    f.write('\n'.join(format(b, '08b') for b in d) + '\n')
print('%s: extension DTDs %s, checksum %02x' %
      (path, ', '.join(m[0] for m in MODES), out[127]))
