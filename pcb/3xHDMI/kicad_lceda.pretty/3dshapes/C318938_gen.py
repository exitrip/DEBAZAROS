"""Generate C318938.step: XKB TS-1101-C-W tact switch, SMD, H 2.5 (outside only).
Datasheet: datasheets/C318938.pdf (rev A2). Run: python C318938_gen.py (needs cadquery).

Frame = KiCad footprint SW-SMD_L6.0-W3.3-LS8.0: centred, pads 1/2 at x = -4/+4,
board top at Z = 0.

Datasheet dimensions used (mm):
  body 6.05 x 3.70; leads 8.00 tip to tip, 0.60 wide, 0.20 thick (card 0.20t)
  top of the cover dome 1.80; top of the actuator 2.50; actuator 2.65 x 1.30
  cover sheet 0.10 (SUS 0.10t)
Scaled from the drawing (no dimension): base height 1.19, dome base 4.45 x 2.65
at Z 1.33, dome top 3.90 x 2.10, lead bend shape, cover side flaps.
"""
import cadquery as cq

BW, BD = 6.05, 3.70           # body length (X) / width incl. cover flaps (Y)
Z_BASE = 1.19                 # top of the black base
TC = 0.10                     # cover sheet
Z_DOME_TOP, Z_ACT_TOP = 1.80, 2.50
ACT_W, ACT_D = 2.65, 1.30


def box(x0, x1, y0, y1, z0, z1):
    return (cq.Workplane("XY").box(x1 - x0, y1 - y0, z1 - z0, centered=False)
            .translate((x0, y0, z0)))


# ---- base (black) ----
base = box(-BW / 2 + TC, BW / 2 - TC, -BD / 2 + TC, BD / 2 - TC, 0.0, Z_BASE)
base = base.edges("|Z").fillet(0.15)

# ---- cover (steel): plate, long-side flaps, end flaps, dome ----
cover = box(-BW / 2 + 0.05, BW / 2 - 0.05, -BD / 2, BD / 2, Z_BASE, Z_BASE + TC)
for s in (-1, 1):
    y0, y1 = sorted((s * (BD / 2 - TC), s * BD / 2))
    cover = cover.union(box(-BW / 2 + 0.25, BW / 2 - 0.25, y0, y1, 0.15, Z_BASE + TC))
    x0, x1 = sorted((s * (BW / 2 - TC), s * BW / 2))
    cover = cover.union(box(x0, x1, -1.25, 1.25, 0.60, Z_BASE + TC))
def rr_wire(w, d, r, z):
    pts = [cq.Vector(x, y, z) for x, y in ((-w/2, -d/2), (w/2, -d/2), (w/2, d/2), (-w/2, d/2))]
    wire = cq.Wire.makePolygon(pts, close=True)
    return wire.fillet2D(r, wire.Vertices())


z0 = Z_BASE + TC
secs = [rr_wire(4.45, 2.65, 0.35, z0), rr_wire(4.45, 2.65, 0.35, 1.33),
        rr_wire(3.90, 2.10, 0.25, Z_DOME_TOP)]
dome = cq.Workplane(obj=cq.Solid.makeLoft(secs, True))
try:
    dome = dome.faces(">Z").edges().fillet(0.10)
except Exception as e:
    print("dome top fillet skipped:", e)
cover = cover.union(dome)

# ---- actuator (white) ----
act = box(-ACT_W / 2, ACT_W / 2, -ACT_D / 2, ACT_D / 2, Z_DOME_TOP - 0.05, Z_ACT_TOP)
act = act.edges("|Z").fillet(0.15).faces(">Z").edges().fillet(0.08)

# ---- leads (silver): gull wing, 0.60 wide, 0.20 thick, tips at +-4.00 ----
prof = [(4.00, 0.0), (3.33, 0.0), (3.00, 0.33), (2.80, 0.33), (2.80, 0.53),
        (3.08, 0.53), (3.41, 0.20), (4.00, 0.20)]
leads = None
for s in (-1, 1):
    pts = [(s * x, z) for x, z in prof]
    l = (cq.Workplane("XZ", origin=(0, 0.30, 0)).polyline(pts).close().extrude(0.60))
    leads = l if leads is None else leads.union(l)

asm = cq.Assembly(name="C318938")
asm.add(base, name="base", color=cq.Color(0.08, 0.08, 0.08))
asm.add(cover, name="cover", color=cq.Color(0.80, 0.80, 0.82))
asm.add(act, name="actuator", color=cq.Color(0.95, 0.95, 0.93))
asm.add(leads, name="leads", color=cq.Color(0.85, 0.85, 0.88))
asm.export("C318938.step")

for nm, w in (("base", base), ("cover", cover), ("actuator", act), ("leads", leads)):
    bb = w.val().BoundingBox()
    print(f"{nm:9s} X {bb.xmin:6.3f}..{bb.xmax:6.3f}  Y {bb.ymin:6.3f}..{bb.ymax:6.3f}"
          f"  Z {bb.zmin:6.3f}..{bb.zmax:6.3f}  valid={w.val().isValid()}")
