"""Generate C709357.step: Kinghelm KH-TYPE-C-16P, USB Type-C receptacle, top mount,
16 SMT tails + 2 pegs + 4 THT shell legs (datasheet datasheets/C709357.pdf).
Run: python C709357_gen.py  (needs cadquery).

Frame = KiCad footprint USB-C-SMD_KH-TYPE-C-16P (3D Y = -footprint y), board top
Z = 0. D = depth from the mating face (rear positive); Y = D - FACE_D.

Datasheet dimensions used (mm):
  opening 8.34 x 2.56 (full-round ends); shell sheet 0.30 -> outside 8.94 x 3.16
  (side walls on the leg centre line: 8.34 + 0.30 = 8.64 = leg c-c)
  shell length 7.35; opening centre 1.67 above the board
  legs: c-c X 8.64, front leg 0.80 wide, rear leg 1.10 wide, c-c D 4.18,
        0.91 below the board
  pegs: dia 0.50, X c-c 5.78, 1.07 in front of the shell rear edge;
        PCB layout: pegs 3.68 behind the front legs, PCB edge 2.60 in front
        of the front legs (= the face)
  tails: 8 x 0.20 at 0.50/1.50/2.50/3.50 c-c, wide tails 2 x 0.24 at 4.80 and
        6.40 c-c; pads 4.18..5.32 behind the front legs
Scaled from the drawing (no dimension): tongue length, latch windows, top
notches, side bracket outline, peg length, tail length past the shell (0.40).
"""
import cadquery as cq

ZC = 1.67                      # opening centre above the board
IN_W, IN_H, T = 8.34, 2.56, 0.30
OUT_W, OUT_H = IN_W + 2 * T, IN_H + 2 * T
L = 7.35
D_FRONT_LEG = L - 1.07 - 3.68  # 2.60 (= PCB edge to front leg, as the layout)
D_REAR_LEG = D_FRONT_LEG + 4.18
D_PEG = L - 1.07
FACE_D = D_FRONT_LEG + 2.415   # footprint front legs at y = +2.415
LEG_X = 8.64 / 2
LEG_DOWN = 0.91


def Y(d):
    return d - FACE_D


def box(x0, x1, d0, d1, z0, z1):
    return (cq.Workplane("XY").box(x1 - x0, d1 - d0, z1 - z0, centered=False)
            .translate((x0, Y(d0), z0)))


def stadium(w, h, d0, d1):
    return (cq.Workplane("XZ", origin=(0, Y(d0), ZC)).slot2D(w, h)
            .extrude(-(d1 - d0)))          # XZ normal is -Y: negative = toward rear


def side_profile(pts_dz, x0, x1):
    pts = [(Y(d), z) for d, z in pts_dz]
    return (cq.Workplane("YZ", origin=(x0, 0, 0)).polyline(pts).close()
            .extrude(x1 - x0))


# ---- shell (metal) ----
shell = stadium(OUT_W, OUT_H, 0, L).cut(stadium(IN_W, IN_H, -0.1, L + 0.1))
try:   # lead-in on the inner front edge
    shell = shell.faces("<Y").edges(cq.selectors.BoxSelector(
        (-IN_W / 2 - 0.01, Y(-0.01), ZC - IN_H / 2 - 0.01),
        (IN_W / 2 + 0.01, Y(0.01), ZC + IN_H / 2 + 0.01))).chamfer(0.08)
except Exception as e:
    print("lead-in chamfer skipped:", e)
z_top_in, z_bot_in = ZC + IN_H / 2, ZC - IN_H / 2
for s in (-1, 1):
    x0, x1 = sorted((s * 1.08, s * 2.40))
    shell = shell.cut(box(x0, x1, 4.78, 5.33, z_top_in - 0.1, ZC + OUT_H / 2 + 0.1))  # latch windows
    # latch bumps inside, top and bottom
    shell = shell.union(box(x0 + 0.15, x1 - 0.15, 4.85, 5.30, z_top_in - 0.15, z_top_in + 0.01))
    shell = shell.union(box(x0 + 0.15, x1 - 0.15, 4.85, 5.30, z_bot_in - 0.01, z_bot_in + 0.15))
    x0, x1 = sorted((s * 1.08, s * 2.70))
    notch = box(x0, x1, 6.10, L + 0.1, z_top_in - 0.1, ZC + OUT_H / 2 + 0.1).edges("|Z and <Y").fillet(0.3)
    shell = shell.cut(notch)                                                     # top rear notches
# bottom rear: shell floor cut where the housing bar with the pegs shows
shell = shell.cut(box(-3.75, 3.75, 5.85, L + 0.1, -0.1, z_bot_in + 0.01))

# side brackets + legs (X centre 4.32, t 0.30)
fl0, fl1 = D_FRONT_LEG - 0.40, D_FRONT_LEG + 0.40
rl0, rl1 = D_REAR_LEG - 0.55, min(D_REAR_LEG + 0.55, L)
bracket = [(1.80, 0.09), (fl0, 0.09), (fl0, -LEG_DOWN), (fl1, -LEG_DOWN), (fl1, 0.09),
           (rl0, 0.09), (rl0, -LEG_DOWN), (rl1, -LEG_DOWN), (rl1, ZC),
           (rl0 - 0.2, ZC), (rl0 - 0.2, 1.50), (1.80, 1.50)]
for s in (-1, 1):
    x0, x1 = sorted((s * (LEG_X - T / 2), s * (LEG_X + T / 2)))
    b = side_profile(bracket, x0, x1)
    b = b.edges("|X").edges(cq.selectors.BoxSelector((-9, -20, -LEG_DOWN - 0.01),
                                                     (9, 20, -LEG_DOWN + 0.01))).fillet(0.25)
    shell = shell.union(b)

# ---- housing (plastic) ----
housing = stadium(IN_W, IN_H, 5.0, L)                                   # rear block
housing = housing.union(box(-3.75, 3.75, 5.85, L, 0.09, z_bot_in + 0.05))  # bottom bar
tongue = box(-6.69 / 2, 6.69 / 2, 0.70, 5.05, ZC - 0.35, ZC + 0.35)
tongue = tongue.edges("|Z and <Y").chamfer(0.3)
housing = housing.union(tongue)
for x in (-5.78 / 2, 5.78 / 2):                                          # pegs dia 0.50
    housing = housing.union(cq.Workplane("XY", origin=(x, Y(D_PEG), -0.53))
                            .circle(0.25).extrude(0.53 + 0.10)
                            .faces("<Z").chamfer(0.1))

# ---- contacts (gold) ----
parts = []
tails = [(-3.35, 0.24), (-3.05, 0.24), (-2.55, 0.24), (-2.25, 0.24),
         (-1.75, 0.20), (-1.25, 0.20), (-0.75, 0.20), (-0.25, 0.20)]
tails += [(-x, w) for x, w in tails]
for x, w in tails:
    parts.append(box(x - w / 2, x + w / 2, 6.95, L + 0.40, 0.0, 0.15))
for i in (1, 4, 5, 6, 7, 8, 9, 12):        # A row on top (A1 at -X), B row below (B1 at +X)
    x = -2.75 + (i - 1) * 0.5
    parts.append(box(x - 0.125, x + 0.125, 1.0, 4.8, ZC + 0.35 - 0.01, ZC + 0.38))
    parts.append(box(-x - 0.125, -x + 0.125, 1.0, 4.8, ZC - 0.38, ZC - 0.35 + 0.01))
contacts = parts[0]
for p in parts[1:]:
    contacts = contacts.union(p)

asm = cq.Assembly(name="C709357")
asm.add(shell, name="shell", color=cq.Color(0.78, 0.78, 0.80))
asm.add(housing, name="housing", color=cq.Color(0.10, 0.10, 0.10))
asm.add(contacts, name="contacts", color=cq.Color(0.86, 0.68, 0.22))
asm.export("C709357.step")

for nm, w in (("shell", shell), ("housing", housing), ("contacts", contacts)):
    bb = w.val().BoundingBox()
    print(f"{nm:9s} X {bb.xmin:7.3f}..{bb.xmax:7.3f}  Y {bb.ymin:7.3f}..{bb.ymax:7.3f}"
          f"  Z {bb.zmin:7.3f}..{bb.zmax:7.3f}  (D {bb.ymin + FACE_D:.3f}..{bb.ymax + FACE_D:.3f})"
          f"  valid={w.val().isValid()}")
