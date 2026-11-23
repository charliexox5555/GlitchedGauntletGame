"""Operator's long Slipframe panels, canted chassis and external optic collars."""

from pathlib import Path

GUN = "Operator"
VERSION = globals().get("VERSION", "r01")
exec(Path("tools/blender/rework_slipframe/roster_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Neon", "Stock")
for name in ("Bolt", "CharmLoop", "Trigger"):
    dress(name)


def receiver_openings(bm):
    for loop in list(boundary_loops(bm)):
        if len(loop) == 4:
            bm.faces.new(loop)
            continue
        assert len(loop) == 8
        # Caps run inside the overlapping handguard and rail footprint.
        center = (1.0967, 0, 0.298) if min(v.co.x for v in loop) > 1.09 else (0.665, 0, 0.4447)
        hub = bm.verts.new(center)
        for first, second in zip(loop, loop[1:] + loop[:1]):
            bm.faces.new((first, second, hub))


dress("Receiver", keep=lambda island: not (0.42 < limits(island, 0)[0] < 0.44 and limits(island, 2)[1] < 0.141),
      close=receiver_openings)
dress("Grip", slots={"Dark": GRIP})
dress("Barrel", keep=lambda island: limits(island, 0)[0] < 3.2, slots={"Metal": FRAME})
dress("Scope", keep=lambda island: not (limits(island, 0)[0] > 1.5 or 0.12 < limits(island, 0)[0] < 0.2),
      slots={"Dark": FRAME, "Metal": FRAME, "Body": FRAME})


def magazine_lips(point):
    if point.z > 0.085 and 0.055 < abs(point.y) < 0.061:
        point.y += math.copysign(0.0032, point.y)


dress("Magazine", slots={"Panel": FACE, "Accent": SHELL}, shape=magazine_lips)


def well_section(z, rear, front, half_width, chamfer):
    return [(x, y, z) for x, y in (
        (rear + chamfer, -half_width), (front - chamfer, -half_width), (front, -half_width + chamfer),
        (front, half_width - chamfer), (front - chamfer, half_width), (rear + chamfer, half_width),
        (rear, half_width - chamfer), (rear, -half_width + chamfer),
    )]


loft("SF_MagwellCollar", [well_section(*s) for s in (
    (0.102, 0.427, 0.837, 0.075, 0.009),
    (0.114, 0.424, 0.840, 0.079, 0.011),
    (0.140, 0.430, 0.835, 0.076, 0.010),
    (0.140, 0.435, 0.830, 0.0644, 0.002),
    (0.114, 0.435, 0.830, 0.0644, 0.002),
    (0.102, 0.432, 0.833, 0.0670, 0.004),
)], FRAME, loop=True)

left_mantle = [
    (0.079, 0.183), (0.109, 0.318), (0.174, 0.328), (0.754, 0.326), (0.878, 0.403),
    (1.086, 0.411), (1.166, 0.356), (1.102, 0.210), (0.965, 0.160), (0.429, 0.182),
]
right_mantle = [
    (0.079, 0.173), (0.114, 0.269), (0.665, 0.283), (0.805, 0.312), (0.894, 0.403),
    (1.086, 0.411), (1.166, 0.356), (1.102, 0.210), (0.965, 0.160), (0.429, 0.178),
]
receiver = side("SF_ReceiverMantle_Left", left_mantle, 0.078, 0.104, SHELL, bevel=0.0048)
right = side("SF_ReceiverMantle_Right", right_mantle, -0.078, -0.102, SHELL, bevel=0.0048)
seat = [(0.183, 0.255), (0.214, 0.308), (0.722, 0.306), (0.676, 0.238), (0.191, 0.238)]
recess(receiver, "SF_ReceiverInsertSeat_Left", seat, 0.089, 0.15)
slide = side("SF_InspectSlidingPanel_Left", [(0.197, 0.259), (0.225, 0.301),
             (0.700, 0.299), (0.669, 0.257)], 0.086, 0.099, FACE, bevel=0.0012)
slide["flat_group"] = "SFInspectPanel"
inlay = side("SF_SeamInlay_Left", [(0.216, 0.246), (0.230, 0.251), (0.660, 0.251), (0.655, 0.245)],
             0.086, 0.095, SEAM, bevel=0.0005)
inlay["flat_group"] = "SFSeam"
recess(right, "SF_ServiceSeat_Right", [(0.215, 0.199), (0.258, 0.252), (0.721, 0.258),
       (0.674, 0.208)], -0.087, -0.15)
side("SF_ServicePanel_Right", [(0.230, 0.207), (0.270, 0.244), (0.702, 0.250), (0.670, 0.215)],
     -0.084, -0.096, FACE, bevel=0.0015)

fore = folded("SF_ForeEnd", (
    (1.042, 0.169, 0.430, 0.082, 0.402, 0.222, 0.052),
    (1.159, 0.177, 0.452, 0.096, 0.419, 0.235, 0.060),
    (1.390, 0.193, 0.451, 0.097, 0.414, 0.247, 0.058),
    (1.798, 0.215, 0.451, 0.097, 0.414, 0.270, 0.058),
    (2.120, 0.234, 0.451, 0.097, 0.414, 0.285, 0.056),
    (2.249, 0.283, 0.442, 0.072, 0.423, 0.311, 0.050),
    (2.315, 0.318, 0.434, 0.058, 0.419, 0.335, 0.036),
), [FRAME, SHELL, SHELL, SHELL, SHELL, FRAME])
paired_faces(fore, "ForeEndPanel",
             [(1.185, 0.327), (1.291, 0.397), (2.143, 0.397), (2.080, 0.320), (1.187, 0.291)],
             [(1.198, 0.330), (1.297, 0.389), (2.115, 0.389), (2.067, 0.328), (1.199, 0.302)],
             0.076, 0.073, 0.090)
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(fore, f"SF_LowerRelief_{label}", [(1.547, 0.275), (1.595, 0.294),
        (1.996, 0.301), (1.954, 0.283)], 0.079 * sign, 0.15 * sign)

stock = side("SF_StockFrame", [
    (-1.125, 0.297), (-0.559, 0.305), (-0.324, 0.295), (0.060, 0.297),
    (0.076, 0.230), (0.029, 0.162), (-0.298, 0.154), (-0.389, 0.049),
    (-0.583, -0.080), (-0.703, -0.172), (-0.803, -0.211), (-1.120, -0.205),
], -0.071, 0.071, SHELL, bevel=0.008)
recess(stock, "SF_StockWindow", [(-1.033, 0.196), (-0.504, 0.218), (-0.426, 0.173),
       (-0.582, 0.008), (-0.779, -0.112), (-1.035, -0.136)], -0.13, 0.13)
side("SF_StockShoe", [
    (-1.3195, 0.328), (-1.285, 0.379), (-1.121, 0.370), (-1.078, 0.331),
    (-1.085, -0.166), (-1.135, -0.216), (-1.279, -0.205), (-1.312, -0.162),
], -0.081, 0.081, GRIP, bevel=0.010)
side("SF_CheekRest", [
    (-1.030, 0.337), (-1.000, 0.404), (-0.931, 0.424), (-0.552, 0.420),
    (-0.442, 0.382), (-0.501, 0.338), (-0.656, 0.320), (-0.704, 0.275),
    (-0.826, 0.275), (-0.871, 0.331),
], -0.063, 0.063, FRAME, bevel=0.007)

brake = folded("SF_BrakeCrown", (
    (3.177, 0.320, 0.451, 0.060, 0.436, 0.338, 0.046),
    (3.228, 0.298, 0.472, 0.077, 0.452, 0.318, 0.054),
    (3.440, 0.298, 0.472, 0.077, 0.452, 0.318, 0.054),
    (3.521, 0.317, 0.455, 0.064, 0.437, 0.335, 0.047),
    (3.521, 0.355, 0.415, 0.032, 0.406, 0.364, 0.023),
    (3.228, 0.355, 0.415, 0.031, 0.406, 0.363, 0.023),
    (3.177, 0.356, 0.415, 0.031, 0.406, 0.364, 0.023),
), [FRAME, SHELL, SHELL, SHELL, FRAME, FRAME, FRAME], loop=True)
for sign, label in ((1, "Left"), (-1, "Right")):
    for i, x in enumerate((3.253, 3.365)):
        recess(brake, f"SF_BrakeFacet_{label}_{i}", [(x, 0.356), (x + 0.030, 0.414),
               (x + 0.094, 0.414), (x + 0.070, 0.356)], 0.046 * sign, 0.13 * sign)


def optic_rim(name, stations, roles):
    sections = [[(x, radius * math.sin(i * math.tau / 12 + math.pi / 12),
                  0.602 + radius * math.cos(i * math.tau / 12 + math.pi / 12))
                 for i in range(12)] for x, radius in stations]
    return loft(name, sections, roles, loop=True)


optic_rim("SF_ScopeFrontCollar", (
    (1.347, 0.136), (1.395, 0.149), (1.492, 0.150), (1.554, 0.147), (1.580, 0.141),
    (1.580, 0.135), (1.493, 0.132), (1.347, 0.124),
), [SHELL, FACE, FACE, SHELL, FRAME, FRAME, FRAME, FRAME])
optic_rim("SF_ScopeRearCollar", (
    (-0.068, 0.102), (-0.040, 0.117), (0.069, 0.117), (0.116, 0.102), (0.156, 0.100),
    (0.156, 0.089), (0.046, 0.096), (-0.068, 0.095),
), [SHELL, FRAME, FACE, SHELL, FRAME, FRAME, FRAME, FRAME])

result = finish_master(fore)
