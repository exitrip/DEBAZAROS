"""Generate C111617.step: HDMI type A receptacle, right angle, SMT + 4 THT shell legs
(SZFENG drawing C111617.png, lip detail C111617-detail.png).
Run: python C111617_gen.py  (needs cadquery).

Frame = KiCad footprint HDMI-SMD_HDMI-019S (3D Y = -footprint y), board top at Z = 0.
D = depth from the mating face (rear positive); Y = D - FACE_D.

Drawing dimensions used (mm):
  shell width 14.90, shell height 6.10, sheet t 0.45 -> opening 14.00 x 4.55
  board -> tongue top 3.70; latch springs / dimples 5.00 apart (bottom)
  legs: c-c X 14.50, t 0.45; front leg 1.0 wide, 2.03 below the board; the side
  walls and the front leg roots start 3.50 behind the face (in front of that only
  the HDMI-profile tube = the lip); rear leg 2.0 wide, 2.43 below the board
  (8.53 - 6.10); rear leg centre 10.55 from the face, leg c-c 6.0
  body (shell) 10.85, overall 11.55 (rear leg rear edge = pin tips)
  19 pins 0.2 wide, pitch 0.5 (18 x 0.5 = 9.00), 1.30 exposed behind the housing
Scaled from the drawing (no dimension): lip bend radii and the shoulder/45 deg
taper, spring slots, top windows, tongue width/thickness.
"""
import cadquery as cq
from cadquery import Vector as V

FACE_D = 4.55 + 3.379          # footprint: front leg centre at y = +3.379 -> face
W, H, T = 14.90, 6.10, 0.45
Z_OPEN_TOP = H - T              # 5.65
Z_OPEN_BOT = Z_OPEN_TOP - 4.55  # 1.10 (opening floor; tube underside at 0.65)
BODY_L = 10.85
SIDE_D = 3.50                   # side walls / front leg roots start here
LEG_X = 14.50 / 2
PIN_TIP_D = 11.55
PIN_ROOT_D = PIN_TIP_D - 1.30   # housing rear edge at the pins


def Y(d):
    return d - FACE_D


def box(x0, x1, d0, d1, z0, z1):
    return (cq.Workplane("XY")
            .box(x1 - x0, d1 - d0, z1 - z0, centered=False)
            .translate((x0, Y(d0), z0)))


def side_profile(pts_dz, x0, x1):
    """Extrude a (D, Z) polygon along X from x0 to x1."""
    pts = [(Y(d), z) for d, z in pts_dz]
    return (cq.Workplane("YZ", origin=(x0, 0, 0)).polyline(pts).close()
            .extrude(x1 - x0))


def prism(wire, d0, d1):
    w = wire.translate(V(0, Y(d0), 0))
    return cq.Workplane(obj=cq.Solid.extrudeLinear(cq.Face.makeFromWires(w),
                                                    V(0, d1 - d0, 0)))


def u_slot(xc, d0, d1, z0, z1, w=2.0, slit=0.3):
    """U-shaped spring cut: slot of width w, rounded front end at d0, minus the
    spring tongue (attached at the rear)."""
    def stadium(width, dstart):
        r = width / 2
        return (cq.Workplane("XY", origin=(0, 0, z0))
                .center(xc, Y(dstart + r)).circle(r).extrude(z1 - z0)
                .union(box(xc - r, xc + r, dstart + r, d1, z0, z1)))
    return stadium(w, d0).cut(stadium(w - 2 * slit, d0 + slit).union(
        box(xc - w, xc + w, d1 - 0.001, d1 + 1, z0 - 1, z1 + 1)))


# ---- lip / shell tube: opening profile (opening side of the sheet), Y = 0 plane ----
half = [(-7.0, Z_OPEN_TOP), (-7.0, 2.45), (-6.2, 2.40), (-4.9, Z_OPEN_BOT)]
pts = half + [(-x, z) for x, z in reversed(half)]
inner = cq.Wire.makePolygon([V(x, 0, z) for x, z in pts], close=True)


def near(wire, xz, r):
    vs = [v for v in wire.Vertices()
          if any(abs(v.X - s * xz[0]) < 1e-3 and abs(v.Z - xz[1]) < 1e-3 for s in (1, -1))]
    return wire.fillet2D(r, vs)


inner = near(inner, (-7.0, Z_OPEN_TOP), 0.55)   # -> outer R 1.0
inner = near(inner, (-7.0, 2.45), 0.50)         # side -> shoulder
inner = near(inner, (-6.2, 2.40), 0.70)         # shoulder -> 45 deg taper (S bend)
inner = near(inner, (-4.9, Z_OPEN_BOT), 0.50)   # taper -> floor
outer = inner.offset2D(T, "arc")[0]

tube = prism(outer, 0, BODY_L).cut(prism(inner, -0.1, BODY_L + 0.1))
try:   # small lead-in on the inner front edge
    tube = tube.faces("<Y").edges(cq.selectors.BoxSelector(
        (-7.01, Y(-0.01), 1.09), (7.01, Y(0.01), 5.66))).chamfer(0.12)
except Exception as e:
    print("lead-in chamfer skipped:", e)

shell = tube
# spring slots: bottom pair at X +-2.5 (5.00), top pair, three windows each side on top
for xc in (-2.5, 2.5):
    shell = shell.cut(u_slot(xc, 0.8, 4.4, Z_OPEN_BOT - T - 0.1, Z_OPEN_BOT + 0.1))
    shell = shell.union(box(xc - 0.5, xc + 0.5, 1.3, 2.1,
                            Z_OPEN_BOT - 0.01, Z_OPEN_BOT + 0.35))   # dimple
for xc in (-3.9, 3.9):
    shell = shell.cut(u_slot(xc, 1.9, 6.4, Z_OPEN_TOP - 0.1, H + 0.1, w=2.1))
    shell = shell.union(box(xc - 0.4, xc + 0.4, 2.3, 3.0,
                            Z_OPEN_TOP - 0.3, Z_OPEN_TOP + 0.01))    # dimple
    for dx in (-0.7, 0, 0.7):
        shell = shell.cut(box(xc + dx - 0.27, xc + dx + 0.27, 7.3, 8.4,
                              Z_OPEN_TOP - 0.1, H + 0.1))

# side walls from D 3.50 back, flush with the tube sides, down to the board
for s in (-1, 1):
    x0, x1 = sorted((s * (W / 2 - T), s * W / 2))
    shell = shell.union(side_profile([(SIDE_D, 0), (BODY_L, 0), (BODY_L, 3.3),
                                      (SIDE_D + 0.3, 3.3), (SIDE_D, 3.0)], x0, x1))

# front legs: 1.0 wide tab D 4.05..5.05, 2.03 below board, root starts at D 3.50
front_leg = [(3.50, 0.6), (5.55, 0.6), (5.55, 0.0), (5.05, -0.4), (5.05, -1.73),
             (4.85, -2.03), (4.25, -2.03), (4.05, -1.73), (4.05, -0.4), (3.50, 0.0)]
# rear legs: 2.0 wide D 9.55..11.55, 2.43 below board, rising to Z 2.2 behind the shell
rear_leg = [(9.55, 2.2), (11.55, 2.2), (11.55, -2.13), (11.25, -2.43), (9.85, -2.43),
            (9.55, -2.13)]
for s in (-1, 1):
    x0, x1 = sorted((s * (LEG_X - T / 2), s * (LEG_X + T / 2)))
    shell = shell.union(side_profile(front_leg, x0, x1))
    shell = shell.union(side_profile(rear_leg, x0, x1))

# ---- housing (plastic) ----
housing = prism(inner, 8.0, BODY_L)                                      # back wall
housing = housing.union(box(-6.4, 6.4, SIDE_D + 0.1, 9.6, 0, Z_OPEN_BOT - T))  # base
housing = housing.union(box(-5.2, 5.2, 9.6, PIN_ROOT_D, 0, Z_OPEN_BOT - T))    # pin block
tongue = box(-5.8, 5.8, 0.8, 8.05, 2.40, 3.70).edges("|Z and <Y").chamfer(0.4)
housing = housing.union(tongue)

# ---- contacts (gold) ----
parts = []
for n in range(1, 20):
    x = 4.5 - (n - 1) * 0.5                       # pin 1 at +X, as the footprint
    parts.append(box(x - 0.1, x + 0.1, PIN_ROOT_D - 0.35, PIN_TIP_D, 0, 0.2))  # SMT tail
    if n % 2:   # odd = top row of the tongue, even = bottom row
        parts.append(box(x - 0.15, x + 0.15, 1.3, 7.6, 3.70 - 0.01, 3.75))
    else:
        parts.append(box(x - 0.15, x + 0.15, 1.3, 7.6, 2.35, 2.40 + 0.01))
contacts = parts[0]
for p in parts[1:]:
    contacts = contacts.union(p)

asm = cq.Assembly(name="C111617")
asm.add(shell, name="shell", color=cq.Color(0.78, 0.78, 0.80))
asm.add(housing, name="housing", color=cq.Color(0.10, 0.10, 0.10))
asm.add(contacts, name="contacts", color=cq.Color(0.86, 0.68, 0.22))
asm.export("C111617.step")

for nm, w in (("shell", shell), ("housing", housing), ("contacts", contacts)):
    bb = w.val().BoundingBox()
    print(f"{nm:9s} X {bb.xmin:7.3f}..{bb.xmax:7.3f}  Y {bb.ymin:7.3f}..{bb.ymax:7.3f}"
          f"  Z {bb.zmin:7.3f}..{bb.zmax:7.3f}  (D {bb.ymin + FACE_D:.3f}..{bb.ymax + FACE_D:.3f})"
          f"  valid={w.val().isValid()}")
