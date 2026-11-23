"""Vandal's folded receiver, longer lower cheek and sloped brake."""

from pathlib import Path

GUN = "Vandal"
VERSION = globals().get("VERSION", "r01")
exec(Path("tools/blender/rework_slipframe/roster_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Neon", "Pins", "RearSight", "Stock")


def receiver_openings(bm):
    # Close the perimeter around each stock opening without capping its bore.
    bridge_boundary(bm, lambda loop: all(0.12 <= v.co.x <= 0.38 and abs(v.co.z - 0.166) < 0.00005 for v in loop))
    bridge_boundary(bm, lambda loop: all(0.448 <= v.co.x <= 0.729 and 0.1633 <= v.co.z <= 0.1661 for v in loop))


def carrier_foot(point):
    if point.y < 0.08:
        point.y -= 0.0013


def grip_opening(bm):
    opening, = boundary_loops(bm)
    left = sorted((v for v in opening if v.co.y > 0), key=lambda v: v.co.x)
    right = sorted((v for v in opening if v.co.y < 0), key=lambda v: v.co.x)
    assert len(left) == len(right) == 4
    for i, j in ((0, 2), (2, 1), (1, 3)):
        bm.faces.new((left[i], right[i], right[j], left[j]))

dress("Receiver", keep=lambda island: not (
    limits(island, 2)[0] >= 0.344 and limits(island, 0)[0] < 0.0
), slots={"Metal": FRAME}, close=receiver_openings)
dress("ChargingHandle", shape=carrier_foot, slots={"Metal": FRAME})
for name in ("Bolt", "FireSelector", "Trigger", "CharmLoop", "Rail"):
    dress(name)


def palm(point):
    if point.z < -0.20:
        point.x += (point.z + 0.20) * 0.22


def heel(point):
    if point.z < -0.23:
        point.x += (-0.23 - point.z) * 0.30


dress("Grip", slots={"Dark": GRIP, "Body": GRIP}, shape=palm, close=grip_opening)
dress("Mag", slots={"Body": FRAME, "Panel": FACE, "Accent": SHELL}, shape=heel)

receiver = folded("SF_ReceiverMantle", (
    (-0.135, 0.358, 0.399, 0.067, 0.389, 0.370, 0.044),
    (-0.047, 0.352, 0.426, 0.094, 0.418, 0.376, 0.056),
    (0.791, 0.351, 0.435, 0.094, 0.417, 0.376, 0.056),
    (0.810, 0.342, 0.432, 0.095, 0.414, 0.367, 0.056),
    (0.916, 0.263, 0.426, 0.096, 0.407, 0.306, 0.056),
    (1.040, 0.218, 0.419, 0.096, 0.386, 0.254, 0.053),
    (1.122, 0.220, 0.411, 0.080, 0.377, 0.255, 0.045),
), SHELL)
seat = [(0.152, 0.387), (0.205, 0.410), (0.745, 0.409), (0.710, 0.380), (0.174, 0.380)]
recess(receiver, "SF_ReceiverInsertSeat_Left", seat, 0.076, 0.13)
slide = side("SF_InspectSlidingPanel_Left", [(0.170, 0.390), (0.209, 0.405), (0.729, 0.404),
             (0.709, 0.391)], 0.073, 0.089, FACE, bevel=0.0012)
slide["flat_group"] = "SFInspectPanel"
inlay = side("SF_SeamInlay_Left", [(0.199, 0.383), (0.211, 0.387), (0.704, 0.387), (0.694, 0.383)],
             0.074, 0.084, SEAM, bevel=0.0005)
inlay["flat_group"] = "SFSeam"
recess(receiver, "SF_ServiceSeat_Right", seat, -0.076, -0.13)
side("SF_ServicePanel_Right", [(0.173, 0.389), (0.211, 0.403), (0.727, 0.403), (0.708, 0.389)],
     -0.073, -0.089, FACE, bevel=0.0012)

fore = folded("SF_ForeEnd", (
    (0.995, 0.206, 0.392, 0.079, 0.367, 0.229, 0.052),
    (1.080, 0.187, 0.419, 0.102, 0.383, 0.242, 0.052),
    (1.440, 0.171, 0.419, 0.102, 0.383, 0.242, 0.052),
    (1.535, 0.179, 0.419, 0.102, 0.383, 0.242, 0.052),
    (1.650, 0.222, 0.414, 0.068, 0.384, 0.245, 0.042),
    (1.693, 0.236, 0.380, 0.055, 0.365, 0.251, 0.034),
), [FRAME, SHELL, SHELL, SHELL, FRAME])
paired_faces(fore, "ForeEndPanel",
             [(1.130, 0.305), (1.179, 0.369), (1.568, 0.369), (1.531, 0.279), (1.130, 0.265)],
             [(1.141, 0.306), (1.186, 0.361), (1.550, 0.361), (1.523, 0.289), (1.141, 0.275)],
             0.077, 0.074, 0.096)
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(fore, f"SF_LowerRelief_{label}", [(1.157, 0.245), (1.189, 0.260), (1.435, 0.259), (1.400, 0.246)],
           0.079 * sign, 0.15 * sign)

stock = side("SF_StockFrame", [
    (-1.128, 0.401), (-0.477, 0.397), (-0.128, 0.358), (-0.129, 0.234),
    (-0.401, 0.224), (-0.589, 0.199), (-0.964, -0.083), (-1.119, -0.150),
], -0.061, 0.061, SHELL, bevel=0.008)
side("SF_StockShoe", [(-1.252, 0.352), (-1.221, 0.405), (-1.120, 0.410), (-1.098, 0.357),
     (-1.099, -0.138), (-1.157, -0.174), (-1.245, -0.141)], -0.076, 0.076, GRIP, bevel=0.011)
hole = [(-1.050, 0.048), (-0.671, 0.288), (-0.343, 0.321), (-0.432, 0.263),
        (-0.649, 0.224), (-1.050, -0.064)]
recess(stock, "SF_StockWindow", hole, -0.11, 0.11)

dress("Barrel", keep=lambda island: limits(island, 0)[0] < 2.38, slots={"Metal": FRAME})
brake = folded("SF_BrakeCrown", (
    (2.335, 0.243, 0.327, 0.036, 0.313, 0.255, 0.026),
    (2.372, 0.220, 0.354, 0.054, 0.339, 0.233, 0.042),
    (2.456, 0.224, 0.350, 0.058, 0.335, 0.236, 0.046),
    (2.583, 0.224, 0.350, 0.058, 0.335, 0.236, 0.046),
    (2.647, 0.238, 0.342, 0.047, 0.331, 0.249, 0.034),
    (2.647, 0.262, 0.309, 0.025, 0.302, 0.270, 0.019),
    (2.370, 0.261, 0.309, 0.024, 0.302, 0.269, 0.018),
    (2.335, 0.262, 0.308, 0.023, 0.301, 0.270, 0.017),
), [FRAME, SHELL, SHELL, SHELL, SHELL, FRAME, FRAME, FRAME], loop=True)
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(brake, f"SF_BrakeFacet_{label}", [(2.420, 0.275), (2.459, 0.307),
           (2.558, 0.307), (2.527, 0.275)], 0.035 * sign, 0.09 * sign)

dress("FrontSight", keep=lambda island: limits(island, 2)[1] < 0.40 or max(abs(v.co.y) for v in island) < 0.009,
      slots={"Body": FRAME, "Metal": SHELL})
front_profile = [(-0.037, 0.367), (0.037, 0.367), (0.049, 0.436), (0.044, 0.551),
                 (0.032, 0.574), (0.022, 0.565), (0.020, 0.490), (-0.020, 0.490),
                 (-0.022, 0.565), (-0.032, 0.574), (-0.044, 0.551), (-0.049, 0.436)]
loft("SF_FrontSightSaddle", [
    [(1.964 + 0.19 * (z - 0.367), y, z) for y, z in front_profile],
    [(2.084 - 0.18 * (z - 0.367), y, z) for y, z in front_profile],
], FRAME)

outside = [(-0.038, 0.414), (0.038, 0.414), (0.065, 0.485), (0.065, 0.600),
           (0.047, 0.624), (-0.047, 0.624), (-0.065, 0.600), (-0.065, 0.485)]
inside = [(-0.043, 0.496), (0.043, 0.496), (0.054, 0.509), (0.054, 0.596),
          (0.041, 0.612), (-0.041, 0.612), (-0.054, 0.596), (-0.054, 0.509)]
loft("SF_RearSightHood", [[(x, y, z) for y, z in profile] for x, profile in (
    (0.064, outside), (0.092, outside), (0.092, inside), (0.064, inside)
)], [FRAME, SHELL, FRAME, SHELL], loop=True)
result = finish_master(fore)
